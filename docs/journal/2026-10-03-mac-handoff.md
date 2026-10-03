# 2026-10-03: Simplify and hand off to the Mac

**Phase:** cross-cutting
**Related ADRs:** [ADR-0022](../../adr/0022-the-local-aws-environment.md) (item 9 amended), [ADR-0024](../../adr/0024-ci-cd-pipeline-standard.md)

## What happened

The owner is moving the project from the Windows PC to a Mac and asked for a clean, simple handoff: less fluff, minimal
scripts (guidelines instead of porting Windows code), a clean branch strategy, and enough context to continue there.

- Committed and merged the staged ADR-0024 pipeline work with the rest of PR #26.
- Tagged the full history as `archive/windows-era`, then removed from the tree: the PowerShell `dev-up`/`dev-down` scripts,
  the 16 archived ADRs, 36 journal entries, `CONTRIBUTING.md`, `docs/agents/`, the vendored `.claude/skills/` and `.actrc`.
- Wrote `HANDOFF.md` (state, next steps, the unfinished Floci fix, open decisions) and `docs/mac-migration.md` (what the
  scripts did, in order; the Floci quirks they handled; Mac setup; the Apple Silicon image risk).
- Folded the working rules, the owner's standing preferences and the branching strategy (GitHub Flow, squash merges)
  into `CLAUDE.md`; updated the READMEs, ADR index and every reference to removed files.
- Deleted merged branches; set the repository to squash-only merges.

## Why

Docs had grown to about 45,000 words around ~1,100 lines of scripts, and the Windows scripts would not run on a Mac.
History is kept at the tag instead of in the tree. Found while preparing: the 12 app images are amd64-only, so an
Apple Silicon Kubernetes node needs emulation or multi-arch images (HANDOFF item 3).

## Verification

First `main` run after the merge: all 12 images passed the scan gate in CI and were reused; the bot opened #27 with
`tag@digest` pins, which merged. Auto-merge failed because the repository had just become squash-only and the script
asked for a merge commit; fixed in #29, after which the next `main` run reported the pins up to date.

`scripts/check` passed locally (Docker was down, so the Docker-based checks ran only in CI); CI on PR #26 passed before
merging; no Markdown link points at a removed file.

## Learn

- History belongs in git (tags, log), not in the working tree: the present state should fit in one read.
- Check the CPU architecture of every image before moving to Apple Silicon.

## Next

See `HANDOFF.md`.
