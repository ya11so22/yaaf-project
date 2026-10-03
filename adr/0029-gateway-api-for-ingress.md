# ADR-0029: Gateway API instead of Ingress objects

**Status:** accepted (amends [ADR-0022](0022-the-local-aws-environment.md) item 6)
**Date:** 2026-10-03
**Evidence:** designed. The Gateway API and Traefik facts below come from their documentation and are to be confirmed on the pinned versions when implementing.

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
2. **The Gateway API CRDs** (the standard channel, version pinned) are installed by an Argo CD Application at an earlier
   sync wave than anything that uses them (ADR-0026).
3. **Traefik** enables its Kubernetes Gateway provider; one `GatewayClass` and one `Gateway` (HTTP listener) live in
   the `traefik` namespace.
4. **Each hostname is an `HTTPRoute`** in the namespace of the service it routes to (`shop`, `argocd`, `headlamp`;
   `grafana` later), attached to the shared Gateway, with a `ReferenceGrant` where a route crosses namespaces. This
   is the namespace-ownership split the API is designed for: the platform owns the Gateway, application teams own
   their routes.
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
