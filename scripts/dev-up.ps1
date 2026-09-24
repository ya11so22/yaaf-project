<#
.SYNOPSIS
  Brings the local AWS (Floci) up and reconciles everything OpenTofu owns on it (ADR-0022).
  Idempotent: safe to run any number of times.

.DESCRIPTION
  1. starts Docker Desktop if the engine is not running, and waits for it
  2. starts Floci and its dashboard (infra/environments/dev/compose.yaml) and waits for Floci's health check
  3. applies the bootstrap root: the S3 bucket that holds the other roots' state
  4. applies the foundation root: VPC, EKS, ECR, IAM, the ingress ALB and the portal website
  5. writes the `floci` AWS CLI profile and the kubeconfig, and requires the cluster API and every node to be Ready.
     If the cluster is broken (Floci can leave k3s dead after an abrupt stop), removes the k3s container and its
     volume, lets Floci recreate it, and repeats 4 and 5 once. k3s state is disposable: Argo CD restores the
     workloads from git.
  6. applies the cluster root: Argo CD and the Applications it reconciles from git
  7. waits for Argo CD, checks each URL, and prints where everything is

.PARAMETER Revision
  The git revision Argo CD tracks (default main). A branch name tries a change before it is merged; run plain
  dev-up again after the branch is merged and deleted, or Argo CD keeps tracking a branch that no longer exists.
.PARAMETER PlanOnly
  Starts Floci, then runs tofu plan instead of apply (bootstrap, and foundation once its state bucket exists).
#>
[CmdletBinding()]
param(
    [string]$Revision = "main",
    [switch]$PlanOnly
)

# Windows PowerShell 5.1 turns any native-command stderr into a terminating error under "Stop", so native calls
# are checked through their exit codes instead.
$ErrorActionPreference = "Continue"

$Endpoint = "http://localhost:4566"
$Region = "us-east-1"
$AwsProfile = "floci"
$Cluster = "yaaf-dev"
$K3sName = "floci-eks-$Cluster"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$DevDir = Join-Path $RepoRoot "infra\environments\dev"
$ComposeFile = Join-Path $DevDir "compose.yaml"
$Roots = @{
    Bootstrap  = Join-Path $DevDir "bootstrap"
    Foundation = Join-Path $DevDir "foundation"
    Cluster    = Join-Path $DevDir "cluster"
}
$script:KubeContext = $null

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

function Assert-Tools {
    $missing = @("docker", "tofu", "aws", "kubectl") | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) }
    if ($missing) {
        Write-Step ("Missing tools: {0}. Install them and re-run (see infra/README.md)." -f ($missing -join ", "))
        exit 1
    }
}

function Start-Docker {
    if ((Invoke-Native docker @("info")).Code -eq 0) { return }
    Write-Step "Docker is not running; starting Docker Desktop"
    $null = Invoke-Native docker @("desktop", "start")
    $up = Wait-Until "the Docker engine" 300 { (Invoke-Native docker @("info")).Code -eq 0 }
    if (-not $up) { Write-Step "Docker did not start. Start Docker Desktop by hand and re-run."; exit 1 }
}

function Start-Floci {
    Write-Step "Starting Floci and floci-dash, waiting for Floci's health check"
    # --remove-orphans removes containers from earlier versions of the compose file (for example floci-ui).
    Assert-Ok (Invoke-Native docker @("compose", "-f", $ComposeFile, "up", "-d", "--wait", "--remove-orphans")) "docker compose up"
}

# init, then plan or apply, in one root. The bootstrap root keeps local state; the others use the S3 backend.
function Invoke-Tofu {
    param([string]$Dir, [string]$Verb, [string[]]$ExtraArgs = @())
    Push-Location $Dir
    try {
        Assert-Ok (Invoke-Native tofu @("init", "-input=false", "-no-color")) "tofu init ($Dir)"
        if ($Verb -eq "plan") {
            $r = Invoke-Native tofu (@("plan", "-input=false", "-no-color") + $ExtraArgs)
        } else {
            $r = Invoke-Native tofu (@("apply", "-input=false", "-auto-approve", "-no-color") + $ExtraArgs)
        }
        Assert-Ok $r "tofu $Verb ($Dir)"
        Write-Host (($r.Output -split "`n" | Where-Object { $_ -cmatch "^(Apply complete|No changes|Plan:)" }) -join "`n")
    } finally {
        Pop-Location
    }
}

function Get-TofuOutputs([string]$Dir) {
    Push-Location $Dir
    try { $r = Invoke-Native tofu @("output", "-json") } finally { Pop-Location }
    if ($r.Code -ne 0) { return $null }
    try { return ($r.Output | ConvertFrom-Json) } catch { return $null }
}

# Writes the `floci` AWS CLI profile (the kubectl IAM user's key, the region and Floci's endpoint) and points the
# kubeconfig at the cluster. Floci's port for the cluster can change when its container is recreated, which is why
# this runs on every check. Returns $false until the foundation root has created the key.
function Update-AccessConfig {
    $out = Get-TofuOutputs $Roots.Foundation
    if (-not $out -or -not $out.kubectl_access_key_id -or -not $out.kubectl_secret_access_key) { return $false }
    $settings = @(
        @("aws_access_key_id", $out.kubectl_access_key_id.value),
        @("aws_secret_access_key", $out.kubectl_secret_access_key.value),
        @("region", $Region),
        @("endpoint_url", $Endpoint)
    )
    foreach ($kv in $settings) {
        $null = Invoke-Native aws @("configure", "set", $kv[0], $kv[1], "--profile", $AwsProfile)
    }
    $arn = Invoke-Native aws @("eks", "describe-cluster", "--name", $Cluster, "--profile", $AwsProfile, "--query", "cluster.arn", "--output", "text")
    if ($arn.Code -ne 0) { return $false }
    $script:KubeContext = $arn.Output.Trim()
    (Invoke-Native aws @("eks", "update-kubeconfig", "--name", $Cluster, "--profile", $AwsProfile)).Code -eq 0
}

function Invoke-Kubectl([string[]]$Arguments) {
    Invoke-Native kubectl (@("--context", $script:KubeContext) + $Arguments)
}

function Test-ClusterReady {
    if ((Invoke-Kubectl @("get", "--raw=/readyz", "--request-timeout=8s")).Code -ne 0) { return $false }
    (Invoke-Kubectl @("wait", "--for=condition=Ready", "node", "--all", "--timeout=10s")).Code -eq 0
}

# Removes the cluster's k3s container and data volume and restarts Floci, which recreates the cluster from scratch on
# the next EKS API call. Safe only because k3s state is disposable.
function Repair-Cluster {
    Write-Step "Repairing: removing the k3s container and volume ($K3sName), then restarting Floci"
    $null = Invoke-Native docker @("rm", "-f", $K3sName)
    $null = Invoke-Native docker @("volume", "rm", "-f", $K3sName)
    Assert-Ok (Invoke-Native docker @("compose", "-f", $ComposeFile, "restart", "floci")) "docker compose restart"
    Start-Floci
}

# Argo CD's view of the workload. A warning, not a failure: the cluster is what this script guarantees, and an
# Application can lag, or be degraded by what is in git.
function Show-ArgoStatus {
    $ok = Wait-Until "the Argo CD applications to be Synced and Healthy" 300 {
        $r = Invoke-Kubectl @("-n", "argocd", "get", "applications", "-o", "jsonpath={range .items[*]}{.status.sync.status}/{.status.health.status} {end}")
        $states = @($r.Output.Trim() -split " " | Where-Object { $_ })
        $r.Code -eq 0 -and $states.Count -gt 0 -and -not ($states | Where-Object { $_ -ne "Synced/Healthy" })
    }
    Write-Host (Invoke-Kubectl @("-n", "argocd", "get", "applications")).Output
    if (-not $ok) { Write-Step "WARNING: not every application is Synced and Healthy (revision '$Revision'). Inspect: kubectl -n argocd get applications" }
}

# Calls a URL and reports whether it answers. curl.exe, because Windows PowerShell 5.1 will not set a Host header
# and *.localhost names do not resolve for every command-line tool on Windows.
# With -Expect, the page must also contain that text: Floci answers 200 on port 4566 even when no site matches.
function Test-Url([string]$Label, [string]$Url, [string]$HostHeader = "", [string]$Expect = "", [int]$TimeoutSec = 240) {
    $curlArgs = @("-s", "-m", "5")
    if ($HostHeader) { $curlArgs += @("-H", "Host: $HostHeader") }
    $ok = Wait-Until $Label $TimeoutSec {
        if ($Expect) { return (Invoke-Native curl.exe ($curlArgs + $Url)).Output.Contains($Expect) }
        (Invoke-Native curl.exe ($curlArgs + @("-o", "NUL", "-w", "%{http_code}", $Url))).Output.Trim() -match "^(200|30[0-9]|401|403)$"
    }
    if ($ok) { "OK  " } else { "DOWN" }
}

function Show-Summary {
    $out = Get-TofuOutputs $Roots.Foundation
    $portalHost = if ($out -and $out.portal_domain_name) { $out.portal_domain_name.value } else { $null }
    $portal = if ($portalHost) { "http://${portalHost}:4566/" } else { $null }

    Write-Host ""
    Write-Step "Checking every endpoint"
    $rows = @(
        @("Portal (S3 + CloudFront)", "http://127.0.0.1:4566/", $portalHost, $portal, "dev portal"),
        @("AWS console (floci-dash)", "http://localhost:9877", "", "http://localhost:9877", ""),
        @("Argo CD", "http://127.0.0.1:8080/", "argocd.localhost", "http://argocd.localhost:8080", ""),
        @("Headlamp", "http://127.0.0.1:8080/", "headlamp.localhost", "http://headlamp.localhost:8080", ""),
        @("Shop", "http://127.0.0.1:8080/", "shop.localhost", "http://shop.localhost:8080", "")
    )
    foreach ($row in $rows) {
        if (-not $row[3]) { continue }
        $state = Test-Url $row[0] $row[1] $row[2] $row[4]
        Write-Host ("  {0}  {1,-26} {2}" -f $state, $row[0], $row[3])
    }
    Write-Host ""
    Write-Host "Open the links in a regular browser. Argo CD login: admin, password from"
    Write-Host "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}'  (base64)"
    Write-Host "AWS CLI:  aws --profile $AwsProfile s3 ls"
}

function Invoke-DevUp {
    Assert-Tools
    Start-Docker
    Start-Floci

    if ($PlanOnly) {
        Write-Step "Plan only: bootstrap"
        Invoke-Tofu $Roots.Bootstrap "plan"
        $bucketExists = (Invoke-Native aws @("s3api", "head-bucket", "--bucket", "yaaf-dev-tfstate", "--endpoint-url", $Endpoint, "--region", $Region, "--no-sign-request")).Code -eq 0
        if ($bucketExists) {
            Write-Step "Plan only: foundation"
            Invoke-Tofu $Roots.Foundation "plan"
        } else {
            Write-Step "The state bucket does not exist yet, so foundation cannot be planned until bootstrap is applied."
        }
        return
    }

    Write-Step "Applying bootstrap (the state bucket)"
    Invoke-Tofu $Roots.Bootstrap "apply"

    for ($attempt = 1; $attempt -le 2; $attempt++) {
        Write-Step "Applying foundation (attempt $attempt)"
        Invoke-Tofu $Roots.Foundation "apply"
        Write-Step "Waiting for the cluster API and nodes"
        $ready = Wait-Until "the cluster to be Ready" 180 { (Update-AccessConfig) -and (Test-ClusterReady) }
        if ($ready) { break }
        if ($attempt -eq 2) {
            Write-Step "The cluster is still not healthy after a repair. Last k3s log lines:"
            Write-Host (Invoke-Native docker @("logs", "--tail", "25", $K3sName)).Output
            exit 1
        }
        Repair-Cluster
    }
    Write-Host (Invoke-Kubectl @("get", "nodes")).Output

    Write-Step "Applying cluster (Argo CD, tracking '$Revision')"
    Invoke-Tofu $Roots.Cluster "apply" @("-var", "target_revision=$Revision", "-var", "kubeconfig_context=$($script:KubeContext)")
    Show-ArgoStatus
    Show-Summary
    Write-Step "Done."
}

# Dot-sourcing (". .\dev-up.ps1") loads the functions without running anything, for testing.
if ($MyInvocation.InvocationName -ne ".") {
    $logDir = Join-Path $env:LOCALAPPDATA "yaaf"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $null = Start-Transcript -Path (Join-Path $logDir "dev-up.log") -Append
    try { Invoke-DevUp } finally { $null = Stop-Transcript }
}
