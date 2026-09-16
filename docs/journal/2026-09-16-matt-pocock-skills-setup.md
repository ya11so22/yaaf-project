# 2026-09-16: Wired up the vendored skills to this repo's conventions

**Phase:** Pre-Phase-1 (setup)
**Related ADRs:** none — configuration, not an architecture decision

## What happened

Ran `/setup-matt-pocock-skills` against the freshly-scaffolded repo. Exploration surfaced a
naming collision before writing anything: the root `CONTEXT.md` vendored in the previous step
was `mattpocock/skills`' *own* terminology doc (defining terms like "Issue tracker" and "Triage
role" for his skill system), not this project's domain glossary — and the setup skill's
`domain-modeling` convention expects the root `CONTEXT.md` to be the project's own.

Resolved by:

- Moving the vendored file to `.claude/skills/CONTEXT.md` (its natural home).
- Creating a fresh, empty root `CONTEXT.md` scaffold for this project's actual domain terms, to
  be filled in lazily via `/domain-modeling` as terms actually get resolved rather than written
  speculatively now.
- Adding `CLAUDE.md` with the `## Agent skills` config block.
- `docs/agents/issue-tracker.md`: GitHub via `gh`, external-PRs-as-request-surface off (solo
  project).
- `docs/agents/triage-labels.md`: the five default labels, unchanged.
- `docs/agents/domain.md`: single-context, pointed at `/adr` (this project's existing
  convention) instead of the skill's default `docs/adr`.

## Why

Writing over the collision silently would have made the project's real domain glossary
indistinguishable from Matt Pocock's own tooling vocabulary — the first person (or agent) to
run `/domain-modeling` later would have been confused about what was already there. Catching it
during exploration, before writing anything, avoided a rename/cleanup later.

## Verification

Reviewed the diff before committing: `git status --short` showed exactly the expected
move-plus-new-file pattern (`A .claude/skills/CONTEXT.md`, `M CONTEXT.md`), no unintended
changes elsewhere.

## Next

Domain terms get added to `CONTEXT.md` lazily as the project actually needs them — no action
item here, just noting the convention is now correctly wired.
