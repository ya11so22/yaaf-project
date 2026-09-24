<#
.SYNOPSIS
  Shuts the local AWS (Floci) down safely, so scripts/dev-up.ps1 can bring everything back (ADR-0014).

.DESCRIPTION
  1. backs up the two OpenTofu state files, which exist only on this machine (they are gitignored)
  2. stops Floci gracefully, then anything Floci started (the cluster, the registry)
  3. optionally quits Docker Desktop, to give the memory back

  It removes nothing. The Docker volumes (Floci's data, the cluster's datastore, the registry's images)
  and the state files are kept, so dev-up.ps1 restores the environment: the cluster is recreated and
  Argo CD redeploys the workloads from git. Never use `docker compose down -v`, `docker volume prune`, or
  Docker Desktop's "Clean / Purge data" or "Reset to factory defaults" to shut down: those delete the state.

.PARAMETER QuitDocker
  Also quits Docker Desktop (docker desktop stop).
.PARAMETER NoBackup
  Skips the state-file backup.
.PARAMETER DryRun
  Shows what would be stopped, and does the backup, but stops nothing.
.PARAMETER BackupRoot
  Where backups go (default $HOME\yaaf-backup). The newest 5 are kept.
#>
[CmdletBinding()]
param(
    [switch]$QuitDocker,
    [switch]$NoBackup,
    [switch]$DryRun,
    [string]$BackupRoot = (Join-Path $HOME "yaaf-backup"),
    [int]$KeepBackups = 5
)

# Windows PowerShell 5.1 turns any native-command stderr into a terminating error under "Stop".
# Native calls are checked through their exit codes instead.
$ErrorActionPreference = "Continue"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ComposeFile = Join-Path $RepoRoot "infra\environments\floci\compose.yaml"
$StateFiles = @(
    @{ Name = "floci";         Path = Join-Path $RepoRoot "infra\environments\floci\terraform.tfstate" },
    @{ Name = "floci-cluster"; Path = Join-Path $RepoRoot "infra\environments\floci-cluster\terraform.tfstate" }
)

function Write-Step([string]$Message) {
    Write-Host ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message)
}

function Invoke-Native {
    param([string]$Exe, [string[]]$Arguments)
    $lines = & $Exe @Arguments 2>&1 | ForEach-Object { "$_" }
    [pscustomobject]@{ Code = $LASTEXITCODE; Output = ($lines -join "`n") }
}

# Copies the state files (they hold resource IDs, the emulator's kubectl IAM key and the smee channel ID,
# and are not on GitHub) into a timestamped folder, and keeps the newest few.
function Backup-State {
    $present = @($StateFiles | Where-Object { Test-Path $_.Path })
    if ($present.Count -eq 0) {
        Write-Step "No OpenTofu state files found; nothing to back up."
        return $true
    }
    $dest = Join-Path $BackupRoot (Get-Date -Format "yyyyMMdd-HHmmss")
    $copied = 0
    try {
        New-Item -ItemType Directory -Force -Path $dest -ErrorAction Stop | Out-Null
        foreach ($f in $present) {
            $target = Join-Path $dest $f.Name
            New-Item -ItemType Directory -Force -Path $target -ErrorAction Stop | Out-Null
            Copy-Item -Path $f.Path -Destination $target -ErrorAction Stop
            # Trust the file that is there, not the absence of an error.
            if (-not (Test-Path (Join-Path $target "terraform.tfstate"))) { throw "copy of $($f.Name) did not produce a file" }
            $copied++
        }
    } catch {
        Write-Step "WARNING: the state backup FAILED (backup folder: $BackupRoot): $($_.Exception.Message)"
        return $false
    }
    Write-Step ("Backed up {0} state file(s) to {1}" -f $copied, $dest)

    $old = Get-ChildItem -Path $BackupRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -Skip $KeepBackups
    foreach ($d in $old) { Remove-Item -Recurse -Force -Path $d.FullName -ErrorAction SilentlyContinue }
    return $true
}

function Stop-Environment {
    $info = Invoke-Native docker @("info")
    if ($info.Code -ne 0) {
        Write-Step "Docker is not running, so there is nothing to stop."
        return
    }

    if ($DryRun) {
        $running = (Invoke-Native docker @("ps", "--format", "{{.Names}}")).Output -split "`n" | Where-Object { $_ -match "floci" }
        Write-Step ("Dry run: would stop Floci gracefully, then: {0}" -f (($running | Where-Object { $_ }) -join ", "))
        return
    }

    # Floci stops the cluster's container itself on a graceful shutdown and keeps its data volume.
    Write-Step "Stopping Floci gracefully"
    $r = Invoke-Native docker @("compose", "-f", $ComposeFile, "stop")
    if ($r.Code -ne 0) { Write-Step "WARNING: docker compose stop reported a problem:"; Write-Host $r.Output }

    # Anything Floci started that is still running (the registry, and the cluster if Floci did not get to it).
    $left = (Invoke-Native docker @("ps", "-q", "--filter", "label=floci=true")).Output -split "`n" | Where-Object { $_ }
    if ($left) {
        Write-Step ("Stopping {0} container(s) Floci started" -f @($left).Count)
        $null = Invoke-Native docker (@("stop") + $left)
    }

    $still = (Invoke-Native docker @("ps", "--format", "{{.Names}}")).Output -split "`n" | Where-Object { $_ -match "floci" }
    if ($still) { Write-Step ("WARNING: still running: {0}" -f ($still -join ", ")) }
    else { Write-Step "Floci and everything it started is stopped. Volumes and state are kept." }
}

$backupOk = $true
if (-not $NoBackup) { $backupOk = Backup-State }
Stop-Environment

if ($QuitDocker -and -not $DryRun) {
    Write-Step "Quitting Docker Desktop"
    $q = Invoke-Native docker @("desktop", "stop")
    if ($q.Code -ne 0) { Write-Step "WARNING: could not quit Docker Desktop from the command line; quit it from the tray icon."; Write-Host $q.Output }
}

if (-not $backupOk) {
    Write-Host ""
    Write-Host "WARNING: the state files were NOT backed up. They are still on disk under infra\environments\, and nothing was deleted; keep them."
}
Write-Host ""
Write-Host "To bring everything back: start Docker Desktop, then run  .\scripts\dev-up.ps1"
