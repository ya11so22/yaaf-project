# ADR-0011: CD design: image identity, deploy scope and milestone state

**Status:** accepted (settles the open items in [ADR-0010](0010-us-market-positioning-and-ai-phases.md); refines [ADR-0008](0008-phase-reslice-cd-and-team-model.md) item 3)
**Date:** 2026-09-20

## Context

CI builds only the services a change touches (ADR-0007), so at any commit most services have no
image tagged with that commit's SHA. A deploy must still know exactly which image each service runs.
Three questions blocked the CD work.

## Options considered

**Image identity**
1. **Content-hash tags** (chosen): each service's tag is a hash of its source directory. Unchanged
   services keep their existing tag, so a deploy resolves every service to an image that already
   exists, and identical inputs give identical tags.
2. **A moving `main` tag:** simple, but mutable, so a deploy is not reproducible and rollback has
   nothing to point back at.
3. **Build all services on every change:** removes the problem but wastes runner time and undoes
   the path-filtered design.

**Deploy scope:** the 11 base services from `app/kustomize`, without `loadgenerator`; the optional
`shoppingassistantservice` component is excluded because it needs AlloyDB and Gemini.

**Milestone state:** keep OpenTofu state local, inside one job that applies, deploys, verifies and
destroys, with the saved plan encrypted. There is no remote backend to run or pay for, and the
environment is torn down within the same run.

## Decision

1. Tag images by content hash of the service source and pin digests in the overlays, applied with
   the kustomize `images:` transformer (the base points at Google's registry).
2. Deploy the 11 base services without the load generator.
3. The milestone runs as one atomic job with local state and a saved, encrypted plan.
4. Rollback is a redeploy of the previously recorded digests.

## Consequences / trade-offs accepted

- The build pipeline must compute and publish the content-hash tag; a shared base image or
  dependency change outside a service directory would not change its hash, so the hash inputs must
  include any shared build files.
- A failed milestone job that dies before destroy can leave real resources behind; the budget alarm
  and a teardown-on-failure step mitigate this.
- Local state means no concurrent milestone runs, which is acceptable for a single owner.
