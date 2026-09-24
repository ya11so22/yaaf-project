# 2026-09-16: Repo scaffold — ADRs, vendored target app, vendored skills

**Phase:** Pre-Phase-1 (setup)
**Related ADRs:** [ADR-0001](../../adr/archive/0001-target-application-choice.md), [ADR-0002](../../adr/archive/0002-aws-emulation-strategy.md), [ADR-0003](../../adr/archive/0003-eks-ephemeral-vs-ecs-fargate.md)

## What happened

Turned the project brief and the three drafted ADRs into an actual repo. Concretely:

- `adr/`: the four ADRs (template + target app choice + AWS emulation strategy + ephemeral EKS)
  committed as the project's decision record.
- `app/`: vendored Google's Online Boutique (`microservices-demo`) unmodified, pinned at commit
  `72ba613a05f7fcee51cf1d0badff401b6ae7074d`, Apache-2.0 preserved. This is the target
  application per ADR-0001 — someone else's real, complex, polyglot system to build platform
  tooling against, not code written for this project.
- `.claude/skills/`: vendored the 24 promoted `engineering`/`productivity` skills from
  `mattpocock/skills` (MIT, pinned at `6654f6b60cd9d5be8b54c6fafe44346dabeb3b76`), since the
  interactive `/plugin install` path isn't available from a non-interactive session.
- `infra/`, `pipelines/`, `policy/`, `platform/`, `.github/workflows/`: placeholder directories
  for the phased roadmap, each with a README stating what lands there and when.
- Root `README.md` / `CONTRIBUTING.md` / `.gitignore`: attribution (what's Google's, what's
  Matt Pocock's, what's original), the phase roadmap summary, and the cross-phase practices from
  the brief (ADR-first, deliberate failure exercises, DORA metrics, threat model, external
  validation goal).

## Why

The project's whole premise (ADR-0001) is that the target app should be real, complex, and not
written by this project — so the interesting engineering is the platform layer around it, not
app logic. Vendoring rather than referencing keeps the fork self-contained and matches "forked,
not written from scratch" from the brief.

## Verification

`git status`/`git diff` reviewed before committing to confirm no secrets or unexpected files
came in with the vendored app tree. Pushed to `claude/floci-project-setup-0qiung`.

## Next

Run `/setup-matt-pocock-skills` to wire the vendored skills to this repo's actual conventions
(issue tracker, triage labels, domain docs location).
