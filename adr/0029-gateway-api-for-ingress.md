# ADR-0029: Gateway API instead of Ingress objects

**Status:** accepted (amends [ADR-0022](0022-the-local-aws-environment.md) item 6)
**Date:** 2026-10-03
**Evidence:** designed, with the chart facts checked against the pinned versions on 2026-10-05 (`helm template` of Traefik chart 41.6.0 and `traefik-crds` 1.18.0). Not yet run on the cluster.

## Context

Traffic reaches the shop, Argo CD and Headlamp as browser, then `http://<name>.localhost:8080`, then a Floci ALB
(host header preserved), then Traefik's NodePort on the k3s node, then Ingress rules by host. The `Ingress` API is
frozen. The Kubernetes community's ingress-nginx project was retired in March 2026, and Gateway API (v1.4, production
ready since October 2025) is its stated successor. Traefik, already used here, supports both. The owner also wants to
learn the API, so the change comes with a guide.

## Options considered

1. **Keep `Ingress`.** Works today; it is the API the ecosystem is leaving.
2. **Gateway API with Traefik** (chosen): no new component, the API platform teams are moving to.
3. **Gateway API with the AWS Load Balancer Controller.** The AWS-native shape, but Floci emulates the ALB itself, so
   there is no controller to run.
4. **Another implementation (Envoy Gateway, Cilium).** More parts, no gain for one cluster.

## Decision

1. **Gateway API replaces the `Ingress` objects** for the shop, Argo CD and Headlamp. The ALB in front, its target group
   and Traefik's NodePort stay as they are.
2. **The Gateway API CRDs** are installed by an Argo CD Application (`deploy/apps/gateway-api-crds.yaml`) from Traefik's own
   `traefik-crds` chart, pinned (1.18.0, which ships the Gateway API **v1.5.1** standard channel, with `gatewayAPI: true` and
   Traefik's and Hub's CRDs off), at an earlier sync wave than anything that uses them (ADR-0026), with server-side apply because
   the CRDs exceed client-side apply's 256 KiB annotation limit. Traefik v3.7 documents support for Gateway API v1.6.2; the chart
   pairs v1.5.1 with it, and the resources used here (`GatewayClass`, `Gateway`, `HTTPRoute`) are stable in both. A first draft
   vendored the 1.1 MB (20,000-line) upstream bundle into the repository; it was replaced by the chart because nobody can review
   it and it needed a hand-update procedure.
3. **Traefik** enables its Kubernetes Gateway provider and turns the Ingress provider off. The chart creates one
   `GatewayClass` (`traefik`) and one `Gateway` (`traefik-gateway`, in the `traefik` namespace) with a single HTTP listener on
   its `web` entry point (container port 8000, behind NodePort 30080) that accepts routes from every namespace. The Gateway's
   status address is set to `localhost`, the same device the Ingress setup needed, because a NodePort service has no
   load-balancer address to copy.
4. **Each hostname is an `HTTPRoute`** in the namespace of the service it routes to (`boutique`, `argocd`, `headlamp`;
   `grafana` later), attached to the shared Gateway by `parentRefs`. A route's backend is in its own namespace, so no
   `ReferenceGrant` is needed (that object is for a route whose backend is in another namespace). This is the
   namespace-ownership split the API is designed for: the platform owns the Gateway, application teams own their routes.
5. **A guide, `docs/guides/gateway-api.md`**, written with the change: the roles (infrastructure provider, cluster
   operator, application developer), the resources and how they relate, a request traced from the browser through the
   ALB, Traefik and an `HTTPRoute`, and the traps.

## Rationale

Learning the successor API now is cheaper than migrating later, and the split between a platform-owned Gateway and
team-owned routes is the same ownership model the simulated team already uses. Keeping the ALB and NodePort unchanged
limits the change to the routing objects.

## Consequences / trade-offs accepted

- Argo CD's health check for `Ingress` objects needed an address workaround (a published `localhost` status); Gateway
  API objects report their own status conditions, which Argo CD reads, so that workaround is expected to go. To confirm.
- Headlamp, Argo CD and the shop must still work through the Floci ALB with the host header preserved; the acceptance
  check is every URL answering with its own page content (quirk Q4), not a status code.
- If a pinned Traefik version lags the Gateway API version, the CRD version is chosen to match Traefik's supported
  one, not the newest.
