# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the
codebase.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root — this project's own domain terms (not `/app`, which is
  vendored upstream code; see root `README.md`).
- **`/adr`**: read ADRs that touch the area you're about to work in. This project keeps ADRs at
  the repo root under `/adr`, not the skill's default `docs/adr`.

If `CONTEXT.md` has no terms recorded yet, **proceed silently**. Don't flag their absence; don't
suggest creating them upfront. The `/domain-modeling` skill (reached via `/grill-with-docs` and
`/improve-codebase-architecture`) fills it in lazily as terms and decisions get resolved.

## File structure

Single context (this repo):

```
/
├── CONTEXT.md
├── adr/
│   ├── 0000-template.md
│   ├── 0001-target-application-choice.md
│   ├── 0002-aws-emulation-strategy.md
│   └── 0003-eks-ephemeral-vs-ecs-fargate.md
├── app/          ← vendored, not part of this project's own domain
├── infra/
├── pipelines/
├── policy/
└── platform/
```

No `CONTEXT-MAP.md` / multi-context split is expected here: the app under `/app` is vendored
upstream code, not a second bounded context of this project's own domain, and the platform work
itself isn't a monorepo with independent packages.

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a
test name), use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary
explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal: either you're inventing
language the project doesn't use (reconsider) or there's a real gap (note it for
`/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently
overriding:

> _Contradicts ADR-0002 (Floci-first AWS emulation), but worth reopening because…_
