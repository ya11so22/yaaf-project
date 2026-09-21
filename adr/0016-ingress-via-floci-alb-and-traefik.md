# ADR-0016: Ingress: a Floci ALB in front of Traefik

**Status:** accepted (brings the Traefik item forward from Phase 2; extends [ADR-0013](0013-gitops-with-argo-cd-on-long-lived-aws.md))
**Date:** 2026-09-21

## Context

Every tool and the app itself was reached with `kubectl port-forward`: one long-running window per tool,
dropped whenever Docker or the network stalls (it showed up as Headlamp's "lost connection to the
cluster"). The owner wants an ingress instead. On Floci only the k3s API port is published from the
cluster's container to the host, so an ingress controller inside the cluster is not reachable from a
browser on its own.

A spike against Floci showed its ELBv2 has a real data path: an ALB with an HTTP listener bound on the
Floci host, and an `ip` target group pointing at the k3s node container's NodePort, returned HTTP 200 from
the `frontend` service. Two details from it: the ALB replaces the `Host` header unless
`preserve_host_header` is on, and target health stays `initial` although traffic flows.

Options considered:

| Option | Verdict |
|---|---|
| Floci ALB → Traefik | Chosen. AWS-faithful, fully in infrastructure code, one published port. Depends on Floci's ELBv2 data plane, which the spike showed working. |
| A proxy container in compose → Traefik NodePort | Simple and sturdy, but one more container and not an AWS mirror. The alternative if Floci's ALB later misbehaves. |
| Traefik plus one `port-forward` | Still a port-forward. |
| k3s hostPort or servicelb | Not possible: Floci publishes only the API port from the cluster container. |
| ingress-nginx | Archived in March 2026. |

## Decision

1. **Route:** browser → `http://<name>.localhost:8080` → a Floci ALB (listener on port 8080, published on
   `127.0.0.1` only, in `compose.yaml`) → an `ip` target group pointing at the k3s node container's
   NodePort (30080) → Traefik → Ingress rules by host name → the Service.
2. **The ALB is OpenTofu** in the `floci` (AWS layer) root, as a module: load balancer with
   `preserve_host_header` on, target group, target attachment (the node's container name, which Docker
   DNS resolves on the shared network), listener. On real AWS the same module points at instances or IPs.
3. **Traefik is installed by Argo CD** from its official Helm chart, pinned (41.6.0, Traefik v3.7.13), as
   a NodePort service on 30080, no TLS entrypoint. The Ingress status address is set to `localhost`, so
   Argo CD reports Ingresses Healthy (it otherwise waits for a load-balancer address that a NodePort
   service never gets).
4. **Kubernetes Ingress, not Gateway API,** for now: it is enough for host-based routing and Traefik supports
   both, so Gateway API can be adopted with the Phase 3 canary work.
5. **Host names** are `argocd.localhost`, `headlamp.localhost` and `shop.localhost`, all on port 8080.
   Browsers resolve `*.localhost` to loopback themselves; command-line tools on Windows may not, so use
   `curl -H "Host: ..."` for them. Ingress objects live in git: the shop's next to the app in
   `deploy/dev`, the platform tools' in `deploy/ingress`.
6. **Bound to `127.0.0.1` only,** so nothing else on the owner's network can reach it.

## Consequences / trade-offs accepted

- Publishing port 8080 recreates the Floci container once; `dev-up.ps1` handles it.
- The ALB target is the k3s node's container name, which is stable across cluster recreation (it is derived
  from the cluster name); a real-AWS target would be an IP or instance.
- No TLS locally. Real AWS would terminate TLS at the load balancer with ACM, which Floci can also emulate.
- Target health reports `initial`, not `healthy`, and the ALB health check is set to accept 200 to 404
  because Traefik answers 404 for hosts it has no rule for. That is a Floci health-check quirk and is
  cosmetic while traffic flows.
- A tool's UI is only as protected as its own login: this is loopback-only and read-only tooling, not an
  authenticated gateway.
- This replaces the Phase 2 Traefik milestone item.
