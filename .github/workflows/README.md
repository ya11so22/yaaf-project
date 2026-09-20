# GitHub Actions workflows

| Workflow | What it does |
|---|---|
| `build.yml` | Path-filtered per-service builds. `.github/scripts/changed-services.sh` works out which `app/src/<service>` folders changed and emits a matrix; each service builds and pushes to a throwaway Floci registry started in its own job. Builds everything if the base commit is unusable or the workflow/script itself changed. |

Planned next (see `docs/milestones.md`):

- `tofu plan` on PR against Floci, with the plan posted as a PR comment.
- `tofu apply` on merge.
- Builds pushing to real ECR through the OIDC roles (ADR-0006) at the AWS milestone.

Third-party actions are pinned to full commit SHAs with the version in a comment.
