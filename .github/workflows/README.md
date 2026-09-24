# GitHub Actions workflows

Design and reasoning: [ADR-0023](../../adr/0023-build-and-delivery.md).

| Workflow | Required check | What it does |
|---|---|---|
| `build.yml` | `build` | Finds changed `app/src/<service>` folders (`.github/scripts/changed-services.sh`, tested by `changed-services.test.sh`), builds each for amd64 with a per-service cache, scans with Trivy (report-only, SARIF to the Security tab) and pushes `ghcr.io/<owner>/<repo>/<service>:<sha>`. Fork PRs build only. No Floci, no `tofu`, no AWS. |
| `infra.yml` | `infra` | On changes under `infra/`: `fmt`, `validate` for all three dev roots, and a `plan` of the foundation on a local backend (no Floci), posted as one sticky PR comment; then a smoke test on a fresh Floci that applies the bootstrap root, applies the foundation on its S3 backend, requires a no-changes re-plan, and destroys it. Re-runs on `main` after merge. |
| `check.yml` | `check` | Runs `scripts/check --ci`: `tofu fmt -check`, the script tests, `actionlint`, and a full-history `gitleaks` scan. The same script the local pre-commit hook runs ([ADR-0009](../../adr/0009-local-pre-gate.md)). |
| `bump-images.yml` | | After a successful build on `main`, opens one PR as the GitHub App bot that bumps the image pins in `deploy/dev`, with auto-merge on. |
| `cleanup.yml` | | Weekly: keeps the newest 10 versions of each image on GHCR. Also runnable by hand. |

Both `build` and `infra` are gate jobs that always run, so a PR that touches nothing relevant
still reports the required check (a workflow-level `paths:` filter would leave it pending).

Third-party actions are pinned to full commit SHAs with the version in a comment.

Not built yet: the pre-merge deploy check (apply the dev roots to a throwaway Floci, install Argo CD, sync the PR's
commit, wait for `Synced` and `Healthy`). It replaces the interim push-based `deploy.yml`, removed on 2026-09-24.

## Running locally with act

`.actrc` maps `ubuntu-latest` to `catthehacker/ubuntu:act-latest` (about 0.6 GB compressed, close
enough to GitHub's runner for these workflows) so [act](https://github.com/nektos/act) and the
GitHub Local Actions VS Code extension run without their interactive image prompt. Pull the image
once first (`docker pull catthehacker/ubuntu:act-latest`), because `.actrc` sets `--pull=false`.

Verified locally: `changes` (both workflows) and `plan`. Do not run these locally:

- `infra.yml` `smoke`: it uses your local Floci's container names, port 4566 and data volume, and
  ends with `docker compose down -v`, which deletes that volume (the whole local AWS and its state).
- `build.yml` `image` with a push-style event: it can log in to GHCR and push. Use a fork-PR event
  payload and `--matrix service:<name>` to build one image without pushing.

act ignores `concurrency`, `timeout-minutes` and OIDC, and has no Actions cache token, so the
`type=gha` build cache does not work under it.

