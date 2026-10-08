# GitHub Actions workflows

The standard every workflow here follows, and the checklist for writing a new one:
[D24](../../PLAN.md#d24) and the [pipeline guide](../../docs/guides/ci-cd-pipeline-standard.md).
Delivery model (GitOps, content tags, rollback): [D23](../../PLAN.md#d23).

| Workflow | Required check | Runs on | What it does |
|---|---|---|---|
| `check.yml` | `check` | every PR and `main` | `scripts/check --ci`, the same script as the pre-commit hook ([D9](../../PLAN.md#d9)): `tofu fmt`, the script tests, Kubernetes schema validation of every `deploy/` directory (kubeconform), workflow security (zizmor, online) and lint (actionlint), full-history secret scan (gitleaks). |
| `build.yml` | `build` | every PR and `main` | Finds changed services under `app/src` and calls `reusable-container-image.yml` for each. On `main` only, the `pins` job then opens or updates one GitHub App bot PR pinning every service to `tag@digest` in `deploy/dev`. |
| `reusable-container-image.yml` | | called by `build` | One image: build, scan (HIGH and CRITICAL to the Security tab), gate (fails on a fixable CRITICAL not accepted in `.trivyignore.yaml`). On `main` only: push by digest, attest SLSA provenance and a CycloneDX SBOM. Pull requests never push. |
| `infra.yml` | `infra` | changes under `infra/` | `fmt`, `validate` of all three dev roots, a `plan` of the foundation (PR comment), an IaC misconfiguration scan (Trivy, report-only), and a smoke test on a fresh Floci: bootstrap, apply on the S3 backend, re-plan must be empty, destroy. |
| `rescan.yml` | | weekly | Re-scans the deployed images (the digests pinned in `deploy/dev`) for vulnerabilities published since they were built. |
| `scorecard.yml` | | weekly and `main` | OpenSSF Scorecard: the repository's supply-chain practices, scored and published. |
| `cleanup.yml` | | weekly | Keeps the newest 10 versions of each image on GHCR. |
| `environment.yml` | | PRs touching `deploy/`, `infra/`, the tasks or tool pins; `main`; by hand | The whole environment from git on an arm64 runner (`mise run up --strict`): Floci, the three roots, Argo CD at the commit under test, every Application Synced and Healthy, the shop and Argo CD answering; torn down. The deploy check and continuous verification ([D31](../../PLAN.md#d31), [D32](../../PLAN.md#d32)); the build time is the platform's measured recovery time. Not yet required. |
| `edge-check.yml` | | by hand | Proves the public edge ([D33](../../PLAN.md#d33), [D38](../../PLAN.md#d38)): a test page through the named Cloudflare tunnel at `check.yaafsome.fyi`, and Cloudflare Access in front of `argocd.` and `grafana.yaafsome.fyi` but not `shop.`. Reads the tunnel token from the `demo` environment; setup in the [tunnel guide](../../docs/guides/cloudflare-tunnel-and-access.md). |

Also in `.github/`: `dependabot.yml` (weekly updates of action SHAs, the compose file's image digests and the OpenTofu
providers, each with a 7-day cooldown) and `CODEOWNERS`. The accepted-findings baseline for the scan gate is
`.trivyignore.yaml` at the repository root.

Verify a published image: `gh attestation verify oci://ghcr.io/ya11so22/yaaf-project/<service>@<digest> --repo ya11so22/yaaf-project`.

The pre-merge deploy check is `environment.yml` (above); making it a required check is the owner's branch-protection call.

## Running locally

`scripts/check` runs the same fast checks as the `check` workflow (also from the pre-commit hook). Everything else runs
on GitHub: the repository is public, so Actions minutes are free, and the workflows depend on things that only exist
there (the build cache token, OIDC for attestations, the bot's App token).
