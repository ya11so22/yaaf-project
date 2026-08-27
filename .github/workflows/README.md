# GitHub Actions workflows

Empty until Floci is set up and Phase 1 starts. Planned first workflows (see root README and
ADR-0002/0003):

- Build + push each of the 11 `/app` services on change only (path-filtered).
- `terraform plan` on PR (against Floci in CI), plan output posted as a PR comment.
- `terraform apply` on merge.
- OIDC federation to AWS for the real-AWS milestone validation runs.
