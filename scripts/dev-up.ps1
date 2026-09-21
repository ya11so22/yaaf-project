<#
.SYNOPSIS
  Brings the long-lived local AWS (Floci) up cleanly and reconciles everything OpenTofu owns on it.
  Idempotent: safe to run any number of times, by hand or at login (ADR-0014).

.DESCRIPTION
  1. waits for the Docker engine
  2. starts Floci and waits for its health check
  3. tofu apply on infra/environments/floci (the drift detection; it also makes Floci restore its
     EKS cluster, which it only does when the EKS API is first called)
  4. refreshes the kubeconfig and requires the cluster API and every node to be Ready
  5. if the cluster is not healthy, wipes the k3s container and its volume, lets Floci recreate it,
     and repeats 3 and 4 once. k3s state is disposable; workloads come back from git (ADR-0013).
  6. tofu apply on infra/environments/floci-cluster: Argo CD and the Application that reconciles
     the workload from git, then reports what Argo CD sees.

.PARAMETER Register
  Runs this script at every login (per-user, no admin needed) via the HKCU Run key.
.PARAMETER Unregister
  Removes that login entry.
.PARAMETER PlanOnly
  Runs tofu plan (infra/environments/floci only) instead of apply and stops. For trying the script safely.
.PARAMETER Revision
  The git revision Argo CD tracks (default main). Use a branch name to try a change before it is merged.
#>
[CmdletBinding()]
param(
    [switch]$Register,
    [switch]$Unregister,
    [switch]$PlanOnly,
    [string]$Revision = "main",
    [string]$Cluster = "yaaf-floci",
    [string]$Endpoint = "http://localhost:4566",
    [string]$Region = "us-east-1",
    [string]$AwsProfile = "floci",
    [string]$Repo = "ya11so22/yaaf-project"
)

# Windows PowerShell 5.1 turns any native-command stderr into a terminating error under "Stop".
# Native calls are checked through their exit codes instead.
$ErrorActionPreference = "Continue"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$EnvDir = Join-Path $RepoRoot "infra\environments\floci"
$ClusterEnvDir = Join-Path $RepoRoot "infra\environments\floci-cluster"
$ComposeFile = Join-Path $EnvDir "compose.yaml"
$RunKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$RunName = "yaaf-dev-up"
$K3sName = "floci-eks-$Cluster"

function Write-Step([string]$Message) {
    Write-Host ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message)
}

function Invoke-Native {
    param([string]$Exe, [string[]]$Arguments)
    $lines = & $Exe @Arguments 2>&1 | ForEach-Object { "$_" }
    [pscustomobject]@{ Code = $LASTEXITCODE; Output = ($lines -join "`n") }
}

function Wait-Until {
    param([string]$What, [int]$TimeoutSec, [scriptblock]$Test, [int]$IntervalSec = 5)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ($true) {
        if (& $Test) { return $true }
        if ((Get-Date) -gt $deadline) { Write-Step "Timed out waiting for: $What"; return $false }
        Start-Sleep -Seconds $IntervalSec
    }
}

function Assert-Ok($Result, [string]$What) {
    if ($Result.Code -ne 0) {
        Write-Step "FAILED: $What (exit code $($Result.Code))"
        Write-Host $Result.Output
        exit 1
    }
}

function Start-Floci {
    Write-Step "Waiting for the Docker engine"
    $up = Wait-Until "the Docker engine" 300 { (Invoke-Native docker @("info")).Code -eq 0 }
    if (-not $up) { Write-Step "Docker is not running. Start Docker Desktop and re-run."; exit 1 }

    Write-Step "Starting Floci and waiting for its health check"
    Assert-Ok (Invoke-Native docker @("compose", "-f", $ComposeFile, "up", "-d", "--wait")) "docker compose up"
}

function Invoke-Tofu([string]$Verb, [string]$Dir = $EnvDir, [string[]]$ExtraArgs = @()) {
    Push-Location $Dir
    try {
        Assert-Ok (Invoke-Native tofu @("init", "-input=false")) "tofu init ($Dir)"
        if ($Verb -eq "plan") {
            $r = Invoke-Native tofu (@("plan", "-input=false") + $ExtraArgs)
        } else {
            $r = Invoke-Native tofu (@("apply", "-input=false", "-auto-approve") + $ExtraArgs)
        }
        Assert-Ok $r "tofu $Verb ($Dir)"
        Write-Host ($r.Output -split "`n" | Select-Object -Last 4 | Out-String)
    } finally {
        Pop-Location
    }
}

# Writes the kubectl IAM key (an OpenTofu output) into an AWS CLI profile and points the kubeconfig
# at the cluster. Floci's port for the cluster can change when its container is recreated, which is
# why this runs on every check. Returns $false if OpenTofu has not created the key yet.
function Update-Kubeconfig {
    Push-Location $EnvDir
    try {
        $r = Invoke-Native tofu @("output", "-json")
    } finally {
        Pop-Location
    }
    if ($r.Code -ne 0) { return $false }
    try { $out = $r.Output | ConvertFrom-Json } catch { return $false }
    if (-not $out.kubectl_access_key_id -or -not $out.kubectl_secret_access_key) { return $false }

    $set = @(
        @("aws_access_key_id", $out.kubectl_access_key_id.value),
        @("aws_secret_access_key", $out.kubectl_secret_access_key.value),
        @("region", $Region),
        @("endpoint_url", $Endpoint)
    )
    foreach ($kv in $set) {
        $null = Invoke-Native aws @("configure", "set", $kv[0], $kv[1], "--profile", $AwsProfile)
    }
    (Invoke-Native aws @("eks", "update-kubeconfig", "--name", $Cluster, "--profile", $AwsProfile)).Code -eq 0
}

# The cluster API answers and every node is Ready.
function Test-ClusterReady {
    $ctx = "arn:aws:eks:${Region}:000000000000:cluster/$Cluster"
    $api = Invoke-Native kubectl @("--context", $ctx, "get", "--raw=/readyz", "--request-timeout=8s")
    if ($api.Code -ne 0) { return $false }
    $nodes = Invoke-Native kubectl @("--context", $ctx, "wait", "--for=condition=Ready", "node", "--all", "--timeout=10s")
    $nodes.Code -eq 0
}

function Wait-ClusterReady([int]$TimeoutSec = 150) {
    Wait-Until "the cluster API and all nodes to be Ready" $TimeoutSec {
        (Update-Kubeconfig) -and (Test-ClusterReady)
    }
}

# Removes the cluster's k3s container and data volume, then restarts Floci so it recreates the
# cluster from scratch on the next EKS API call. Safe only because k3s state is disposable.
function Repair-Cluster {
    Write-Step "Repairing: removing the k3s container and volume ($K3sName)"
    $null = Invoke-Native docker @("rm", "-f", $K3sName)
    $null = Invoke-Native docker @("volume", "rm", "-f", $K3sName)
    Write-Step "Restarting Floci"
    Assert-Ok (Invoke-Native docker @("compose", "-f", $ComposeFile, "restart", "floci")) "docker compose restart"
    Assert-Ok (Invoke-Native docker @("compose", "-f", $ComposeFile, "up", "-d", "--wait")) "docker compose up"
}

# Registers the GitHub webhook that makes Argo CD refresh on a push instead of at its next poll (ADR-0015):
# a push event to the smee.io channel OpenTofu created. Idempotent, and it removes stale smee hooks left
# by an earlier channel. A warning, not a failure: the cluster works without it, only slower to notice a
# merge. Uses the owner's gh login. The channel URL is a capability, so it is never printed.
function Register-GitHubWebhook {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Step "WARNING: gh is not installed; skipping the GitHub webhook (Argo CD will poll instead)"
        return
    }
    Push-Location $ClusterEnvDir
    try { $out = Invoke-Native tofu @("output", "-json") } finally { Pop-Location }
    if ($out.Code -ne 0) { Write-Step "WARNING: could not read the webhook URL; skipping the GitHub webhook"; return }
    try { $url = ($out.Output | ConvertFrom-Json).webhook_url.value } catch { $url = $null }
    if (-not $url) { Write-Step "WARNING: no webhook_url output yet; skipping the GitHub webhook"; return }

    $list = Invoke-Native gh @("api", "repos/$Repo/hooks")
    if ($list.Code -ne 0) { Write-Step "WARNING: could not list GitHub webhooks (is gh logged in with the repo scope?); skipping"; return }
    $hooks = @($list.Output | ConvertFrom-Json)

    foreach ($h in $hooks) {
        if ($h.config.url -like "https://smee.io/*" -and $h.config.url -ne $url) {
            $null = Invoke-Native gh @("api", "--method", "DELETE", "repos/$Repo/hooks/$($h.id)")
            Write-Step "Removed a stale smee webhook"
        }
    }

    $body = @{
        name   = "web"
        active = $true
        events = @("push")
        config = @{ url = $url; content_type = "json"; insecure_ssl = "0" }
    } | ConvertTo-Json -Depth 5 -Compress

    # The body goes through a temp file, not the pipeline: Windows PowerShell 5.1 pipes text to native
    # commands in an encoding GitHub rejects, and a temp file behaves the same on 5.1 and 7.
    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($tmp, $body, (New-Object System.Text.UTF8Encoding($false)))
        $existing = $hooks | Where-Object { $_.config.url -eq $url } | Select-Object -First 1
        if ($existing) {
            $r = & gh api --method PATCH "repos/$Repo/hooks/$($existing.id)" --input $tmp 2>&1
            $verb = "updated"
        } else {
            $r = & gh api --method POST "repos/$Repo/hooks" --input $tmp 2>&1
            $verb = "created"
        }
    } finally {
        Remove-Item $tmp -ErrorAction SilentlyContinue
    }
    if ($LASTEXITCODE -eq 0) { Write-Step "GitHub webhook $verb (push events to the smee channel)" }
    else { Write-Step "WARNING: could not $verb the GitHub webhook"; Write-Host ($r | Out-String) }
}

# Argo CD's view of the workload. A warning, not a failure: the cluster itself is what this script
# guarantees, and the Application can lag or be degraded for reasons in git (for example a revision
# that does not exist yet).
function Show-ArgoStatus {
    $ctx = "arn:aws:eks:${Region}:000000000000:cluster/$Cluster"
    $healthy = Wait-Until "the Argo CD application to be Synced and Healthy" 300 {
        $r = Invoke-Native kubectl @("--context", $ctx, "-n", "argocd", "get", "application", "online-boutique-dev", "-o", "jsonpath={.status.sync.status} {.status.health.status}")
        $r.Code -eq 0 -and $r.Output.Trim() -eq "Synced Healthy"
    }
    Write-Host (Invoke-Native kubectl @("--context", $ctx, "-n", "argocd", "get", "application")).Output
    if (-not $healthy) {
        Write-Step "WARNING: the application is not Synced and Healthy (revision '$Revision'). Inspect: kubectl -n argocd describe application online-boutique-dev"
    }
}

# Calls each host through the ALB on 127.0.0.1:8080 (ADR-0016). A warning, not a failure: it needs Argo CD to
# have synced Traefik and the Ingress objects, which can lag or be waiting on a git revision. curl.exe is
# used because Windows PowerShell 5.1 will not set a Host header.
function Show-Ingress {
    $hosts = @("argocd.localhost", "headlamp.localhost", "shop.localhost")
    foreach ($h in $hosts) {
        $ok = Wait-Until "$h to answer through the ALB" 240 {
            $r = Invoke-Native curl.exe @("-s", "-m", "5", "-o", "NUL", "-w", "%{http_code}", "-H", "Host: $h", "http://127.0.0.1:8080/")
            $r.Output.Trim() -match "^(200|30[0-9]|401|403)$"
        }
        if ($ok) { Write-Step "  http://${h}:8080  OK" } else { Write-Step "  WARNING: http://${h}:8080 did not answer (is the revision '$Revision' synced?)" }
    }
}

function Show-K3sLog {
    Write-Step "Last k3s log lines:"
    $r = Invoke-Native docker @("logs", "--tail", "25", $K3sName)
    Write-Host $r.Output
}

function Register-Login {
    # Same host that is running this script (PowerShell 7 = pwsh.exe, Windows PowerShell = powershell.exe).
    $hostExe = (Get-Process -Id $PID).Path
    $cmd = "`"$hostExe`" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    Set-ItemProperty -Path $RunKey -Name $RunName -Value $cmd
    Write-Step "Registered: dev-up now runs at every login. Log: $env:LOCALAPPDATA\yaaf\dev-up.log"
}

function Unregister-Login {
    Remove-ItemProperty -Path $RunKey -Name $RunName -ErrorAction SilentlyContinue
    Write-Step "Removed the login entry."
}

function Invoke-DevUp {
    Start-Floci

    if ($PlanOnly) {
        Invoke-Tofu "plan"
        Write-Step "Plan only: stopping before apply."
        return
    }

    for ($attempt = 1; $attempt -le 2; $attempt++) {
        Write-Step "Reconciling infrastructure with tofu apply (attempt $attempt)"
        Invoke-Tofu "apply"
        Write-Step "Waiting for the cluster"
        if (Wait-ClusterReady) {
            Write-Step "Cluster ready."
            $ctx = "arn:aws:eks:${Region}:000000000000:cluster/$Cluster"
            Write-Host (Invoke-Native kubectl @("--context", $ctx, "get", "nodes")).Output
            Write-Step "Reconciling Argo CD (revision '$Revision')"
            Invoke-Tofu "apply" $ClusterEnvDir @("-var", "target_revision=$Revision")
            Register-GitHubWebhook
            Show-ArgoStatus
            Write-Host ""
            Show-Ingress
            Write-Host ""
            Write-Host "Open in a regular browser (not VS Code's built-in one):"
            Write-Host "  Argo CD   http://argocd.localhost:8080     user admin; password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath={.data.password}  (base64)"
            Write-Host "  Headlamp  http://headlamp.localhost:8080   no login (read-only, loopback only)"
            Write-Host "  Shop      http://shop.localhost:8080"
            Write-Step "Done."
            return
        }
        if ($attempt -eq 1) { Repair-Cluster }
    }
    Write-Step "The cluster is still not healthy after a repair."
    Show-K3sLog
    exit 1
}

# Dot-sourcing (". .\dev-up.ps1") loads the functions without running anything, for testing.
if ($MyInvocation.InvocationName -ne ".") {
    $logDir = Join-Path $env:LOCALAPPDATA "yaaf"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $null = Start-Transcript -Path (Join-Path $logDir "dev-up.log") -Append
    try {
        if ($Register) { Register-Login }
        elseif ($Unregister) { Unregister-Login }
        else { Invoke-DevUp }
    } finally {
        $null = Stop-Transcript
    }
}
