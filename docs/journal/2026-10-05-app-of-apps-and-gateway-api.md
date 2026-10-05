# 2026-10-05: Argo CD app-of-apps and Gateway API

**Phase:** cross-cutting (the Mac era, step 3)
**Related ADRs:** [0026](../../adr/0026-argo-cd-app-of-apps.md), [0029](../../adr/0029-gateway-api-for-ingress.md); guide: [Gateway API](../guides/gateway-api.md)

## What happened

- The cluster root now installs only Argo CD, an `AppProject` (`dev`) and one root Application (`platform`). Everything else is an
  Application file in `deploy/apps/`: the Gateway API CRDs, Traefik, the platform routes, Headlamp and its RBAC, and the shop.
- Ingress objects became HTTPRoutes. Traefik's chart creates the GatewayClass and Gateway; each service owns its route.
- `scripts/check` validates Applications and HTTPRoutes against the datreeio CRD schemas, pinned to a commit.
- Wrote the [Gateway API guide](../guides/gateway-api.md) with real output from this cluster.

## Why

The platform half of GitOps was still HCL, so a Traefik change needed `tofu apply`. Gateway API is the successor to Ingress and
splits ownership between the platform (the Gateway) and each service (its route).

## Verification

*Verified on Floci:* from a fresh cluster, `up --revision <branch>` reached 7 Applications Synced and 6 Healthy (the shop is
Progressing, see below). The repo-sourced Applications tracked the branch while the chart-sourced ones kept their chart versions
(the kustomize patch works). The GatewayClass was Accepted, the Gateway Programmed with address `localhost`, and all three routes
attached. Argo CD and Headlamp answered through the Gateway at `:18080`, and an unknown host got 404. **Acceptance test of
ADR-0026:** a label added to the Traefik Application in git reached the live Application in 54 s with no `tofu apply`; reverted.
`check` caught a mistyped route port and a misspelled Application field.

The shop still returns 500: five app pods fail on emulated amd64 (four crash-looping, one OOMKilled). The arm64 pipeline fixes it.

## Mistakes and what they taught

1. **I vendored a 20,000-line CRD bundle into the repository.** The owner asked what it was; it could be installed from Traefik's own
   `traefik-crds` chart in a 30-line Application instead. Before copying large upstream files into a repo, look for a packaged way.
2. **The `argocd-apps` chart prints an AppProject description unquoted**, so a colon followed by a space made invalid YAML. Found by
   running `helm template` with the same values, not by guessing. Render a chart's templates before a long run.
3. **I edited `.mise/tasks/up` while it was running**, and bash read the shifted file and died with a syntax error. Never edit a
   script that is executing; wait for it to finish.
4. **Quirk Q1 is not a dead container.** The repair step caught `status=running exit=0` for a container started a day earlier, so
   the cluster was not dead. Working hypothesis: Floci's k3s registers under a new node name after a restart and the old Node
   object stays NotReady, so "all nodes Ready" never holds. The repair step now prints the node list to settle it.

## Learn

- Gateway API splits routing by owner: GatewayClass (which software), Gateway (which doors), HTTPRoute (where traffic goes).
- A status that says *why* (Accepted, ResolvedRefs, Programmed) is the main practical gain over Ingress.
- An app-of-apps makes platform changes a pull request, and an `AppProject` limits what Argo CD may deploy and from where.

## Next

The arm64 pipeline (ADR-0027): native arm runners, explicit build arguments, the architecture check and `-arm64` content tags. It
fixes the failing app pods and is the first real publish and attestation.
