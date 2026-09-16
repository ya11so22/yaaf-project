## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues (`ya11so22/yaaf-project`), via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical labels, unchanged (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: root `CONTEXT.md` + ADRs at `/adr` (not the skill default `docs/adr`). See `docs/agents/domain.md`.

## Documentation practice

This project's stated goal is to have every decision, step, and milestone documented well
enough to explain and present later, not just to work. This is a standing instruction, not a
one-off: follow it every session without being asked.

- **Decisions** (options considered, trade-offs, what was picked and why) go in `/adr`, written
  *before* implementing, per `CONTRIBUTING.md`.
- **Steps** (what got done in a session, and why, when it doesn't rise to ADR-level) go in
  `docs/journal/`, one file per session or per distinct step: `YYYY-MM-DD-<slug>.md`, using
  `docs/journal/_template.md`. Write one at the end of every session that changed something,
  covering what happened, why (or a link to the ADR that already covers why), how it was
  verified, and what's next. Don't skip this because the change felt small — a short entry beats
  none.
- **Milestones** (phase progress against the brief's "independently demoable" bar) get checked
  off in `docs/milestones.md` as they land.
- **Deliberate failure exercises** (one per phase, per the brief) get written up in
  `docs/postmortems/`.

Update `docs/journal/` and `docs/milestones.md` at the end of every session, unprompted, the
same way commits get made — this is part of finishing the work, not a separate ask.
