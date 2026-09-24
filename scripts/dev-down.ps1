<#
.SYNOPSIS
  Stops the local AWS (Floci) safely, or resets it to nothing (ADR-0022).

.DESCRIPTION
  Default: backs up the OpenTofu state, stops Floci gracefully (Floci then stops the cluster it started) and stops
  anything else Floci started. Nothing is deleted: scripts/dev-up.ps1 brings everything back.

  With -Reset: deletes everything instead, after a confirmation: Floci's data (every resource and the OpenTofu state
  in its S3 bucket), the cluster and its volume, the registry, and the bootstrap root's local state. The next dev-up
  builds the whole environment again from code. Use it for a clean start, or when the environment is beyond repair.

  Do not use Docker Desktop's "Clean / Purge data" or `docker volume prune` instead: they also delete the data, but
  leave the bootstrap state behind, so the next dev-up is out of step with an empty Floci.

.PARAMETER Reset
  Delete everything, as described above. Asks for confirmation; add -Force to skip the question.
.PARAMETER QuitDocker
  Also quit Docker Desktop, to give its memory back.
.PARAMETER NoBackup
  Skip the state backup.
.PARAMETER BackupRoot
  Where backups go (default $HOME\yaaf-backup). The newest 5 are kept.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
    [switch]$Reset,
    [switch]$Force,
    [switch]$QuitDocker,
    [switch]$NoBackup,
    [string]$BackupRoot = (Join-Path $HOME "yaaf-backup"),
    [int]$KeepBackups = 5
)

# Windows PowerShell 5.1 turns any native-command stderr into a terminating error under "Stop", so native calls
# are checked through their exit codes instead.
$ErrorActionPreference = "Continue"

$Endpoint = "http://localhost:4566"
$StateBucket = "yaaf-dev-tfstate"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$DevDir = Join-Path $RepoRoot "infra\environments\dev"
$ComposeFile = Join-Path $DevDir "compose.yaml"
$BootstrapDir = Join-Path $DevDir "bootstrap"

function Write-Step([string]$Message) {
    Write-Host ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message)
}

function Invoke-Native {
    param([string]$Exe, [string[]]$Arguments)
    $lines = & $Exe @Arguments 2>&1 | ForEach-Object { "$_" }
    [pscustomobject]@{ Code = $LASTEXITCODE; Output = ($lines -join "`n") }
}

function Get-Lines([object]$Result) {
    @($Result.Output -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

# Copies the bootstrap root's local state and, while Floci is up, the state bucket (the foundation and cluster
# state), into a timestamped folder. Keeps the newest few.
function Backup-State {
    $dest = Join-Path $BackupRoot (Get-Date -Format "yyyyMMdd-HHmmss")
    try {
        New-Item -ItemType Directory -Force -Path $dest -ErrorAction Stop | Out-Null
        $local = Get-ChildItem -Path $BootstrapDir -Filter "terraform.tfstate*" -ErrorAction SilentlyContinue
        if ($local) {
            New-Item -ItemType Directory -Force -Path (Join-Path $dest "bootstrap") -ErrorAction Stop | Out-Null
            $local | Copy-Item -Destination (Join-Path $dest "bootstrap") -ErrorAction Stop
        }
    } catch {
        Write-Step "WARNING: the state backup failed: $($_.Exception.Message)"
        return
    }
    $s3 = Invoke-Native aws @("s3", "cp", "s3://$StateBucket", (Join-Path $dest "state-bucket"), "--recursive",
        "--endpoint-url", $Endpoint, "--region", "us-east-1", "--profile", "floci")
    if ($s3.Code -ne 0) { Write-Step "Note: the state bucket was not copied (Floci down, or not bootstrapped yet)." }
    Write-Step "State backed up to $dest"

    Get-ChildItem -Path $BackupRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "^\d{8}-\d{6}$" } |
        Sort-Object Name -Descending | Select-Object -Skip $KeepBackups |
        ForEach-Object { Remove-Item -Recurse -Force -Path $_.FullName -ErrorAction SilentlyContinue }
}

# Containers Floci started itself (the k3s cluster, the ECR registry, Lambda and RDS containers) carry this label.
function Get-FlociChildren {
    Get-Lines (Invoke-Native docker @("ps", "-aq", "--filter", "label=floci=true"))
}

function Stop-Environment {
    Write-Step "Stopping Floci and floci-dash gracefully"
    $r = Invoke-Native docker @("compose", "-f", $ComposeFile, "stop")
    if ($r.Code -ne 0) { Write-Step "WARNING: docker compose stop reported a problem:"; Write-Host $r.Output }

    $left = Get-Lines (Invoke-Native docker @("ps", "-q", "--filter", "label=floci=true"))
    if ($left) {
        Write-Step ("Stopping {0} container(s) Floci started" -f $left.Count)
        $null = Invoke-Native docker (@("stop") + $left)
    }
    Write-Step "Stopped. Everything is kept; run scripts\dev-up.ps1 to bring it back."
}

function Reset-Environment {
    Write-Step "Removing Floci, floci-dash and Floci's data volume"
    $r = Invoke-Native docker @("compose", "-f", $ComposeFile, "down", "--volumes", "--remove-orphans")
    if ($r.Code -ne 0) { Write-Step "WARNING: docker compose down reported a problem:"; Write-Host $r.Output }

    $children = Get-FlociChildren
    if ($children) {
        Write-Step ("Removing {0} container(s) Floci started" -f $children.Count)
        $null = Invoke-Native docker (@("rm", "-f", "-v") + $children)
    }
    # Volumes Floci created: labelled ones (the ECR registry's), and the cluster's datastore, which is not labelled
    # but is named after its container (floci-eks-<cluster>).
    $labelled = Get-Lines (Invoke-Native docker @("volume", "ls", "-q", "--filter", "label=floci=true"))
    $clusters = Get-Lines (Invoke-Native docker @("volume", "ls", "-q")) | Where-Object { $_ -like "floci-eks-*" }
    foreach ($v in @($labelled) + @($clusters)) { $null = Invoke-Native docker @("volume", "rm", "-f", $v) }

    Get-ChildItem -Path $BootstrapDir -Filter "terraform.tfstate*" -ErrorAction SilentlyContinue | Remove-Item -Force
    Write-Step "Reset done. The next scripts\dev-up.ps1 builds the environment from scratch."
}

if ((Invoke-Native docker @("info")).Code -ne 0) {
    Write-Step "Docker is not running, so there is nothing to stop or reset."
    exit 0
}

if (-not $NoBackup) { Backup-State }

if ($Reset) {
    $what = "Floci's data (every resource and the OpenTofu state), the cluster, and the bootstrap state"
    if ($Force -or $PSCmdlet.ShouldProcess($what, "Delete permanently")) {
        Reset-Environment
    } else {
        Write-Step "Reset cancelled. Nothing was deleted."
        Stop-Environment
    }
} else {
    Stop-Environment
}

if ($QuitDocker) {
    Write-Step "Quitting Docker Desktop"
    $q = Invoke-Native docker @("desktop", "stop")
    if ($q.Code -ne 0) { Write-Step "WARNING: could not quit Docker Desktop from the command line; quit it from the tray icon." }
}
