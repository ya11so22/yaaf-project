# 2026-09-16: Floci running locally — milestone

**Phase:** Phase 1 — AWS IaC + GitHub Actions foundation
**Related ADRs:** [ADR-0002](../../adr/0002-aws-emulation-strategy.md)

## What happened

Got Floci running on the user's machine (Windows, PowerShell, Docker Desktop):

```powershell
docker run -d --name floci `
  -p 4566:4566 `
  -v /var/run/docker.sock:/var/run/docker.sock `
  floci/floci:latest
```

Confirmed with a health check and an actual AWS CLI smoke test against it (S3 bucket create +
list). Along the way, clarified a question about the user's existing `kind` cluster (running via
Docker Desktop): it's unrelated to Floci's EKS emulation. Floci provisions and owns its own
`k3s` cluster internally when Terraform/CLI calls hit the EKS API — it doesn't attach to a
cluster you already have. No migration or change needed; the `kind` cluster stays independent
and unused by this project's Floci-based workflow.

## Why

This is the actual unblock for ADR-0002's "Floci-first for the daily dev loop" strategy — until
Floci runs locally, none of the Phase 1 Terraform work can be iterated against it.

## Verification

```powershell
curl.exe -f http://localhost:4566/_floci/health   # succeeded

$env:AWS_ENDPOINT_URL = "http://localhost:4566"
$env:AWS_ACCESS_KEY_ID = "test"
$env:AWS_SECRET_ACCESS_KEY = "test"
$env:AWS_DEFAULT_REGION = "us-east-1"

aws s3 mb s3://smoke-test   # succeeded
aws s3 ls                   # bucket listed
```

Confirmed directly by the user: "everything is up and running and the s3 bucket was created."

## Next

Start the actual Phase 1 Terraform modules against this running instance, beginning with the
VPC module (see the following journal entry).
