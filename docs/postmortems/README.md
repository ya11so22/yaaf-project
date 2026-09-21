# Postmortems

One entry per deliberate failure exercise, per the brief: at the end of each phase, break
something on purpose (kill a pod mid-deploy, revoke a Floci-emulated IAM permission, corrupt a
model artifact before promotion) and write it up here.

Cheap to do since the environment is ephemeral and free — there's no excuse to skip it.

## Format

One file per exercise: `YYYY-MM-DD-<what-broke>.md`, one paragraph covering:

- What broke (and how it was broken, on purpose)
- Blast radius — what else was affected
- How it was caught (or wasn't, and should have been)
- What changed as a result

## Entries

- [2026-09-21: A broken emailservice through the delivery pipeline](2026-09-21-phase1-bad-emailservice.md): Phase 1. A change that only fails at start-up passes CI and reaches `dev`; readiness contained it; a pin-only revert was undone by the bump workflow, and reverting the source recovered it.
