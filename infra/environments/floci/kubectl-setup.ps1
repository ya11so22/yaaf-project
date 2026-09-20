# Points kubectl at the Floci-backed EKS cluster. Safe to re-run (it rotates the key). With
# persistent storage (compose.yaml) the key survives restarts, so this is normally a one-off;
# re-run it only if Floci's data volume is wiped.
#
# Floci's EKS auth webhook rejects the public test/test key pair, so this creates a real IAM
# user + key in Floci, stores it in an AWS CLI profile named "floci", and merges a kubeconfig
# entry that uses that profile. Existing kubeconfig contexts are left in place.
param(
    [string]$ClusterName = "yaaf-floci",
    [string]$Endpoint = "http://localhost:4566",
    [string]$Region = "us-east-1",
    [string]$UserName = "kubectl-dev",
    [string]$Profile = "floci",
    [string]$KubeconfigPath = ""
)

$ErrorActionPreference = "Stop"

# Admin calls to Floci itself use the public dummy credentials.
$env:AWS_ACCESS_KEY_ID = "test"
$env:AWS_SECRET_ACCESS_KEY = "test"
$env:AWS_DEFAULT_REGION = $Region
$env:AWS_ENDPOINT_URL = $Endpoint

# list-users exits 0 whether or not the user exists; get-user would write to stderr, which
# Windows PowerShell 5.1 treats as a fatal error under $ErrorActionPreference = "Stop".
$existing = aws iam list-users --query "Users[?UserName=='$UserName'].UserName" --output text
if (-not $existing) {
    aws iam create-user --user-name $UserName | Out-Null
}

# An IAM user holds at most two keys; drop old ones so re-runs never hit that limit.
$old = aws iam list-access-keys --user-name $UserName --query "AccessKeyMetadata[].AccessKeyId" --output json | ConvertFrom-Json
foreach ($id in $old) {
    aws iam delete-access-key --user-name $UserName --access-key-id $id
}

$key = (aws iam create-access-key --user-name $UserName --output json | ConvertFrom-Json).AccessKey

Remove-Item Env:AWS_ACCESS_KEY_ID, Env:AWS_SECRET_ACCESS_KEY, Env:AWS_ENDPOINT_URL

aws configure set aws_access_key_id $key.AccessKeyId --profile $Profile
aws configure set aws_secret_access_key $key.SecretAccessKey --profile $Profile
aws configure set region $Region --profile $Profile
aws configure set endpoint_url $Endpoint --profile $Profile

$eksArgs = @("eks", "update-kubeconfig", "--name", $ClusterName, "--profile", $Profile)
if ($KubeconfigPath) { $eksArgs += @("--kubeconfig", $KubeconfigPath) }
aws @eksArgs

Write-Host "Done. Try: kubectl get nodes"
