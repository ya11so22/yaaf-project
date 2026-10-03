# ADR-0026: Argo CD Applications live in git (app-of-apps)

**Status:** accepted (amends [ADR-0022](0022-the-local-aws-environment.md) item 4 and [ADR-0023](0023-build-and-delivery.md) item 2)
**Date:** 2026-10-03
**Evidence:** designed. The pattern is Argo CD's documented one ([declarative setup](https://argo-cd.readthedocs.io/en/release-3.2/operator-manual/declarative-setup/)); the patch mechanism in item 3 is untested.

## Context

The `cluster` root installs Argo CD and also declares every Application as HCL: the shop, Traefik, the platform
ingress, Headlamp's RBAC and Headlamp. Delivery of the workload is GitOps, but changing the platform (a chart version,
a Traefik value) needs a `tofu apply`, so the platform half is not delivered by pull request and Argo CD, the way the
shop is. Every Application also sits in Argo CD's unrestricted `default` project.

## Options considered

1. **Keep the Applications in HCL.** Nothing to change; the gap above stays.
2. **An `ApplicationSet` with a git directory generator.** Less repetition, but Helm-chart sources with values do not
   fit a bare directory, and the generator is one more concept than the problem needs. Kept for the deferred
   per-PR-environments idea.
3. **App-of-apps: one root Application that points at a directory of Application files** (chosen). Plain YAML, one
   file per Application, reviewable in a PR.
4. **Argo CD managing its own installation** as well. Documented and possible; deferred, because OpenTofu installing it
   once is simple and works.

## Decision

1. **OpenTofu (the `cluster` root) installs Argo CD, one `AppProject`, and one root Application** (`platform`). Nothing
   else is declared in HCL.
2. **`deploy/apps/` holds one Application file per thing Argo CD runs**: the shop (`deploy/dev`), Traefik, the Gateway
   API CRDs and Gateway (ADR-0029), Headlamp and its RBAC, and later monitoring. A new platform component is a new file
   in a pull request.
3. **Trying a branch still works.** The root Application renders `deploy/apps` with kustomize and a patch that sets
   `spec.source.targetRevision` on the Applications that point at this repository to the root's own revision
   (`up --revision <branch>`, default `main`). Applications that point at a Helm chart keep their chart versions.
4. **An `AppProject` named `dev` replaces `default`**: allowed sources are this repository and the chart repositories
   in use; the only destination is the local cluster. Least privilege for what Argo CD may deploy and from where.
5. **Order is explicit** with sync waves (CRDs before the resources that use them).
6. The `argocd-apps` chart is kept only if it is the simplest way to create the root Application; otherwise the root is
   one `kubernetes_manifest`. Decided when implementing, by whichever has fewer parts.

## Rationale

GitOps should cover the whole platform, not only the app, or "everything is a pull request" is half true. This is also
the bootstrap pattern the Argo CD documentation describes. The `AppProject` is a small change with a real security
benefit and is what platform interviews ask about.

## Consequences / trade-offs accepted

- Bootstrapping depends on one HCL-created root; losing it means re-running `up`, which recreates it.
- A broken file in `deploy/apps/` can break the root's sync; the pre-merge deploy check (Phase 1 close-out) exists to
  catch that before merge.
- The branch patch is a small amount of cleverness. If it proves fragile, the fallback is documented as "edit the
  `targetRevision` values on the branch", not a second mechanism.
- Acceptance: a fresh `up` reaches all Applications `Synced` and `Healthy` from the files in git, and a Traefik change
  merged as a PR reaches the cluster without `tofu apply`.
