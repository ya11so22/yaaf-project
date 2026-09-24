# 2026-09-20: Email rewritten, repository made public

**Phase:** Phase 1 — Commit to running app
**Related ADRs:** [ADR-0007](../../adr/archive/0007-ci-split-ghcr-and-floci-scope.md), [ADR-0008](../../adr/archive/0008-phase-reslice-cd-and-team-model.md)

## What happened

Steps 1 and 2 of the agreed go-public sequence.

**Email rewrite.** A full audit had found no secrets, but the owner's personal email was in the
commit metadata. Backed up every ref to a bundle, rewrote author and committer emails to the
GitHub noreply address with `git filter-branch` (28 commits; the 5 Claude and 1 GitHub committer
identities untouched), and verified before pushing: no address left in authors, committers or
messages, and every commit's file tree byte-identical to before. The force-push of `main` and the
branch was blocked for the agent by the auto-mode safety check, so the owner ran it with
`--force-with-lease` guards. The remote was then verified: `main` at the new root, the branch at
the local tip, no old address in the remote history. `user.email` was set to the noreply address.

**Going public.** Re-scanned the whole history with gitleaks first (no leaks). Checked that
enforcing SHA pinning would not break any action we use: `trivy-action`'s nested actions are
already pinned to SHAs, and the others have no nested actions. Then, in this order, because
GitHub rejects the fork-approval setting on private repositories (`422`): enforced SHA pinning,
made the repository public, then set the fork-PR approval policy to
`all_external_contributors`. The default workflow token was already read-only.

## Verification

`gh api` reads back `visibility=public`, `sha_pinning_required=true`,
`approval_policy=all_external_contributors`, `default_workflow_permissions=read`.

## Notes

- Force-pushing removes the old commits from the branches, but the old objects can stay reachable
  by SHA on GitHub until it garbage-collects them. The old SHAs were never published.
- Secret scanning and push protection report as disabled; they are free on public repositories and
  are a candidate to enable.
- Branch protection needs the repository public, which it now is, but should wait until the first
  PR has produced the `build` and `infra` checks so they can be selected as required.

## Next

Open the PR from the working branch into `main` for the first real runs of `build` and `infra`.
