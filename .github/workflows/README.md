# GitHub Actions workflows

Design and reasoning: [ADR-0007](../../adr/0007-ci-split-ghcr-and-floci-scope.md).

| Workflow | Required check | What it does |
|---|---|---|
| `build.yml` | `build` | Finds changed `app/src/<service>` folders (`.github/scripts/changed-services.sh`, tested by `changed-services.test.sh`), builds each for amd64 with a per-service cache, scans with Trivy (report-only, SARIF to the Security tab) and pushes `ghcr.io/<owner>/<repo>/<service>:<sha>`. Fork PRs build only. No Floci, no `tofu`, no AWS. |
| `infra.yml` | `infra` | On changes under `infra/`: `fmt`, `validate` and `plan` without Floci, with the plan as one sticky PR comment; then a Floci smoke test that applies `environments/floci` from scratch, requires a no-changes re-plan, and destroys it. Re-runs on `main` after merge. |
| `cleanup.yml` | | Weekly: keeps the newest 10 versions of each image on GHCR. Also runnable by hand. |

Both `build` and `infra` are gate jobs that always run, so a PR that touches nothing relevant
still reports the required check (a workflow-level `paths:` filter would leave it pending).

Third-party actions are pinned to full commit SHAs with the version in a comment.

Not built yet: the manual, environment-gated apply of `aws-milestone` (needs that environment
to exist), and pushing to real AWS through the OIDC roles (ADR-0006).
