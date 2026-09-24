# ADR-0011: CD design: image identity, deploy scope and milestone state

**Status:** superseded by [ADR-0023](../0023-build-and-delivery.md) (consolidated 2026-09-24; kept as the record of how the decision evolved)
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
2. **Semver or git tags:** no. Semver is a compatibility promise to consumers, and these services
   ship together with none; a git tag is per repository, but path-filtered builds leave most
   services unchanged per release, so per-service tags would be needed and with them per-service
   version bookkeeping. A repo-level `v0.x` tag with a digest manifest can be added later if a
   human-readable release marker is wanted.
3. **SHA of the last commit touching the service directory:** equally stable and readable in
   `git log`; differs only in that a revert makes a new tag and a rebuild. Not chosen; the tree hash
   reuses the earlier image.
4. **A moving `main` tag:** simple, but mutable, so a deploy is not reproducible and rollback has
   nothing to point back at.
5. **Build all services on every change:** removes the problem but wastes runner time and undoes
   the path-filtered design.

**Deploy scope:** the base in `app/kustomize` holds 11 workloads; without `loadgenerator` that is 10
services plus the `redis-cart` cache (an earlier draft of this ADR said "11 services"). The optional
`shoppingassistantservice` component is excluded because it needs AlloyDB and Gemini.

**Milestone state:** keep OpenTofu state local, inside one job that applies, deploys, verifies and
destroys, with the saved plan encrypted. There is no remote backend to run or pay for, and the
environment is torn down within the same run.

## Decision

1. Tag images by content hash of the service source. Overlays stay static; a render step pins each
   service through the kustomize `images:` transformer (the base points at Google's registry), so
   rendering at an earlier revision reproduces that deploy. No bot commits are needed.
2. Deploy the 10 services and `redis-cart`, without the load generator.
3. The milestone runs as one atomic job with local state and a saved, encrypted plan.
4. Rollback is a render and deploy at an earlier revision, which reproduces that revision's tags.
   The tags are also written to each deploy's log. GHCR retention (10 versions per package) bounds
   how far back that reaches.

## Consequences / trade-offs accepted

- The build pipeline must compute and publish the content-hash tag; a shared base image or
  dependency change outside a service directory would not change its hash, so the hash inputs must
  include any shared build files.
- A failed milestone job that dies before destroy can leave real resources behind; the budget alarm
  and a teardown-on-failure step mitigate this.
- Local state means no concurrent milestone runs, which is acceptable for a single owner.
