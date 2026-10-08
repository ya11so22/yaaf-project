# Guide: Gateway API, how traffic gets into the cluster

**Related:** [D29](../../PLAN.md#d29) (the decision), [D26](../../PLAN.md#d26) (how it is deployed),
[`deploy/apps/traefik.yaml`](../../deploy/apps/traefik.yaml) (the Gateway), [`deploy/routes/`](../../deploy/routes/argocd.yaml) and
[`deploy/dev/route.yaml`](../../deploy/dev/route.yaml) (the routes), [the local environment guide](local-aws-environment.md)
**Evidence:** verified on Floci (every output below is from this cluster on 2026-10-05); the Gateway API facts are from its
[specification](https://gateway-api.sigs.k8s.io/)

## The idea

A cluster runs many services, but a browser knows one address. Something has to stand at the edge, receive every request,
look at the **hostname** and the **path**, and hand it to the right service. That is *routing*, and Kubernetes has had two APIs
for describing it.

- **Ingress** (the old one) packs everything into one object: which door to listen on, which hostname goes where, and
  controller-specific tricks hidden in annotations. It is frozen; nothing new is being added to it.
- **Gateway API** (the new one) splits the same job into separate objects so that **different people own different parts**:
  - a **GatewayClass** says *which software* does the routing (here, Traefik);
  - a **Gateway** says *which doors are open*: a listener on a port, and who may attach routes to it;
  - an **HTTPRoute** says *where traffic goes*: "requests for `shop.localhost` go to the `frontend` service".

The point of the split is ownership. The people who run the platform own the Gateway (the door). Each team owns the
HTTPRoute for its own service (the sign on the door). A team can change its route without touching, or being able to break,
anyone else's.

```
 platform owns                     each service owns
 ┌──────────────┐   ┌─────────┐   ┌────────────────────┐   ┌─────────┐
 │ GatewayClass │──▶│ Gateway │◀──│ HTTPRoute          │──▶│ Service │
 │  "traefik"   │   │  :8000  │   │ shop.localhost     │   │ frontend│
 └──────────────┘   └─────────┘   └────────────────────┘   └─────────┘
```

## How it works here

A request for the shop travels like this:

```
browser  http://shop.localhost:18080
  ──▶ Floci's ALB, listener 8080 (published on your Mac as 18080)       host header kept
  ──▶ the k3s node, NodePort 30080
  ──▶ Traefik, entry point "web" = container port 8000
  ──▶ the Gateway's listener "web" (port 8000): accepts routes from every namespace
  ──▶ the HTTPRoute whose hostnames match "shop.localhost"
  ──▶ the Service "frontend", port 80, in namespace boutique
```

Three things are set up, all by git ([D26](../../PLAN.md#d26)):

1. **The CRDs.** Kubernetes ships none of these types. `deploy/apps/gateway-api-crds.yaml` installs them from Traefik's
   `traefik-crds` chart. They must exist *before* Traefik starts, which is why that Application has an earlier sync wave.
2. **The Gateway.** Traefik's Helm chart creates a `GatewayClass` named `traefik` and a `Gateway` named `traefik-gateway`
   from the values in `deploy/apps/traefik.yaml`: one HTTP listener, on port 8000, open to routes from every namespace.
3. **The routes.** One HTTPRoute per hostname, in the namespace of the service behind it:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: argocd
  namespace: argocd            # next to the service it routes to
spec:
  parentRefs:                  # "attach me to this Gateway"
    - name: traefik-gateway
      namespace: traefik
      sectionName: web         # and to this listener
  hostnames:
    - argocd.localhost
  rules:
    - backendRefs:             # no "matches": every path goes to this service
        - name: argocd-server
          port: 80
```

**Adding a service** is adding one such file next to it, in a pull request. Nothing about the Gateway changes.

### Look at it on the cluster

```bash
kubectl get gatewayclass,gateway -A
kubectl get httproute -A
kubectl -n traefik get gateway traefik-gateway -o jsonpath='{range .status.conditions[*]}{.type}={.status}{"\n"}{end}'
```

What this cluster showed:

```
Gateway:   Accepted=True  Programmed=True        listener web: attachedRoutes=3
HTTPRoute: Accepted=True  ResolvedRefs=True       (for each of argocd, headlamp, frontend)

curl http://argocd.localhost:18080/               -> HTTP 200
curl -H 'Host: nobody.localhost' http://127.0.0.1:18080/   -> HTTP 404   (no route claims that name)
```

The status is how Gateway API tells you what went wrong, and it is far better than Ingress for this. **Accepted** means the
object is valid and the controller took it. **ResolvedRefs** means the Service it points at exists. **Programmed** means the
data path is actually set up. `attachedRoutes=3` is the Gateway counting the routes that found it.

## Why this way

- **Ingress** works, but it is the API the ecosystem is leaving. The Kubernetes community's own ingress-nginx controller
  was retired in March 2026, and Gateway API is its stated successor. Learning the new one now is cheaper than migrating later.
- **Split ownership is the real gain**, not new syntax. With Ingress, one object mixes the platform's concern (the door) with the
  team's (the route), so either everyone edits shared files or the platform edits for everyone.
- **Why Traefik and not the AWS Load Balancer Controller?** On real AWS you would use the controller to create ALBs from
  Gateways. Floci emulates the ALB itself and there is no controller to run, so Traefik is the controller here, behind an
  ALB that OpenTofu creates. The ALB-to-NodePort hop is unchanged.

## Watch out for

- **A Gateway listener port is the entry point's port, not the one users type.** The listener is `8000`, Traefik's `web`
  entry point inside the container. Port `80` is the Service's port, `30080` is the NodePort, and `18080` is where your Mac
  reaches the ALB. Mix them up and the Gateway shows a problem instead of routing. *This project hit the same shape of
  confusion with `8080`: your own software already held it, so every `*.localhost:8080` request returned someone else's page.*
- **The CRDs must exist first.** A Gateway or route applied before its CRD fails with "no matches for kind". That is why the
  CRD Application syncs before Traefik, and Traefik before the routes (sync waves, D26).
- **A Gateway with no address is not Programmed.** A NodePort Service has no load-balancer address for Traefik to copy, so
  the chart's `statusAddress.hostname` is set to `localhost`. *Found by reading the chart before deploying; verified when the
  Gateway came up `Programmed=True`.*
- **Routes only attach where the listener allows.** The default is "same namespace as the Gateway". Here the listener says
  `from: All`, which is what lets a route in `boutique` or `argocd` attach to a Gateway in `traefik`.
- **Matching is on the name, not the port.** Browsers send `Host: shop.localhost:18080`, but the route says `shop.localhost`,
  and that matches.
- **`ReferenceGrant` is for crossing namespaces.** Not needed here, because each route's backend is in the route's own
  namespace. It becomes necessary the moment a route points at a Service in another namespace, and it must be created by the
  *backend's* owner: the owner of what is being pointed at has to agree.
- **Versions.** The CRDs come in release channels and versions (this cluster has v1.5.1 standard). Use the version your
  controller documents support for. Traefik 3.7 documents v1.6.2 and its chart pairs v1.5.1; the three kinds used here are
  stable in both.

## Check yourself

<details><summary>What does Gateway API do that Ingress could not?</summary>

It splits one object into three, so the platform owns the Gateway (the door) and each team owns its own HTTPRoute (where its
traffic goes), without editing shared files. It also reports clear status (Accepted, ResolvedRefs, Programmed) instead of
leaving you to read controller logs, and it expresses things like header matching and traffic splitting in the API instead of
in controller-specific annotations.

</details>

<details><summary>A new route returns 404. How do you find out why?</summary>

Look at the route's status first: `kubectl describe httproute <name>`. `Accepted=False` means it could not attach, usually
because the parent Gateway name or namespace is wrong, or the listener does not allow routes from that namespace.
`ResolvedRefs=False` means the backend Service name or port is wrong. If both are True, check that the hostname in the
request matches `spec.hostnames`: an unmatched host gets a 404 from the Gateway, as `nobody.localhost` did above.

</details>

<details><summary>Why does the Gateway listen on 8000 when users reach it on 18080?</summary>

Because they are different layers. 18080 is where the Mac reaches the load balancer. The ALB forwards to the node on 30080
(the Service's NodePort), which Kubernetes maps to the pod's `web` port. Traefik's `web` entry point listens on 8000 inside
the container, and a Gateway listener's port must match an entry point's port.

</details>

<details><summary>Who should create a ReferenceGrant, and when?</summary>

The owner of the namespace being pointed *at*, when a route in another namespace needs to use one of its Services. It is a
deliberate yes from the target's owner, so one team cannot quietly route traffic to another team's services. Same-namespace
routes need none.

</details>
