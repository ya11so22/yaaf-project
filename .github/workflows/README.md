# GitHub Actions workflows

The standard every workflow here follows, and the checklist for writing a new one:
[ADR-0024](../../adr/0024-ci-cd-pipeline-standard.md) and the [pipeline guide](../../docs/guides/ci-cd-pipeline-standard.md).
Delivery model (GitOps, content tags, rollback): [ADR-0023](../../adr/0023-build-and-delivery.md).

| Workflow | Required check | Runs on | What it does |
|---|---|---|---|
| `check.yml` | `check` | every PR and `main` | `scripts/check --ci`, the same script as the pre-commit hook ([ADR-0009](../../adr/0009-local-pre-gate.md)): `tofu fmt`, the script tests, Kubernetes schema validation of every `deploy/` directory (kubeconform), workflow security (zizmor, online) and lint (actionlint), full-history secret scan (gitleaks). |
| `build.yml` | `build` | every PR and `main` | Finds changed services under `app/src` and calls `reusable-container-image.yml` for each. On `main` only, the `pins` job then opens or updates one GitHub App bot PR pinning every service to `tag@digest` in `deploy/dev`. |
| `reusable-container-image.yml` | | called by `build` | One image: build, scan (HIGH and CRITICAL to the Security tab), gate (fails on a fixable CRITICAL not accepted in `.trivyignore.yaml`). On `main` only: push by digest, attest SLSA provenance and a CycloneDX SBOM. Pull requests never push. |
| `infra.yml` | `infra` | changes under `infra/` | `fmt`, `validate` of all three dev roots, a `plan` of the foundation (PR comment), an IaC misconfiguration scan (Trivy, report-only), and a smoke test on a fresh Floci: bootstrap, apply on the S3 backend, re-plan must be empty, destroy. |
| `rescan.yml` | | weekly | Re-scans the deployed images (the digests pinned in `deploy/dev`) for vulnerabilities published since they were built. |
| `scorecard.yml` | | weekly and `main` | OpenSSF Scorecard: the repository's supply-chain practices, scored and published. |
| `cleanup.yml` | | weekly | Keeps the newest 10 versions of each image on GHCR. |

Also in `.github/`: `dependabot.yml` (weekly updates of action SHAs, the compose file's image digests and the OpenTofu
providers, each with a 7-day cooldown) and `CODEOWNERS`. The accepted-findings baseline for the scan gate is
`.trivyignore.yaml` at the repository root.

Verify a published image: `gh attestation verify oci://ghcr.io/ya11so22/yaaf-project/<service>@<digest> --repo ya11so22/yaaf-project`.

Not built yet: the pre-merge deploy check (apply the dev roots to a throwaway Floci, load the PR's images, install Argo CD,
sync the PR's commit, wait for `Synced` and `Healthy`).

## Running locally with act

`.actrc` maps `ubuntu-latest` to `catthehacker/ubuntu:act-latest` (about 0.6 GB compressed, close enough to GitHub's runner
for these workflows) so [act](https://github.com/nektos/act) runs without its interactive image prompt. Pull the image once
first (`docker pull catthehacker/ubuntu:act-latest`), because `.actrc` sets `--pull=false`.

Do not run these locally:

- `infra.yml` `smoke`: it uses your local Floci's container names, port 4566 and data volume, and ends with
  `docker compose down -v`, which deletes that volume (the whole local AWS and its state).
- `build.yml` with a push event: it would push images and try to open the bot PR. Use a pull request event payload.

act ignores `concurrency`, `timeout-minutes` and OIDC, has no Actions cache token (so the `type=gha` build cache does not
work), and cannot create attestations.
