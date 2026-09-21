# 2026-09-21: Ingress instead of port-forwards, and a webhook trigger for Argo CD

**Phase:** Phase 1, GitOps delivery (operator experience)
**Related ADRs:** [ADR-0015](../../adr/0015-argocd-webhook-via-smee-relay.md), [ADR-0016](../../adr/0016-ingress-via-floci-alb-and-traefik.md)

## What happened

Two requests from the owner after the first end-to-end run: Argo CD should be triggered by an event, not
by its three-minute poll; and the tools should not need `kubectl port-forward` (a dropped forward showed up
as Headlamp's "lost connection to the cluster").

**Webhook trigger.** Options for a cluster behind NAT were compared from current documentation (smee.io,
ngrok, Cloudflare quick and named tunnels, Tailscale Funnel, polling faster, a self-hosted runner). smee.io
was chosen: free, no account, and the cluster only connects outward, so Argo stays private. Reading the
smee client's source then showed it re-serialises the JSON body, and smee.io parses it server-side, so
GitHub's HMAC signature can never verify through it (GitHub escapes `<` as `\u003c`, and our commits contain
`<noreply@anthropic.com>`). An earlier statement that Argo would reject forged events was wrong for this
route. ADR-0015 records the limitation: no shared secret, the webhook is a poke only (Argo reads the state
from git itself), the channel ID is random and kept out of git, and the real-AWS route (API Gateway or a load
balancer in front of Argo, which Floci can rehearse) restores signature verification. The relay is a
Deployment created by OpenTofu; `dev-up.ps1` is to register the GitHub webhook.

**Ingress.** Floci publishes only the k3s API port, so an in-cluster ingress is not reachable from a browser
by itself. A spike with the AWS CLI showed Floci's ELBv2 has a real data path: an ALB listener bound on the
Floci host and an `ip` target group pointing at the k3s node container's NodePort returned HTTP 200 from
the frontend. Two details: the ALB replaces the Host header unless `preserve_host_header` is on, and target
health stays `initial` while traffic flows. ADR-0016 records the design: an ALB (OpenTofu module, listener on
`127.0.0.1:8080`) in front of Traefik (Argo CD, chart 41.6.0, NodePort 30080), plain Kubernetes Ingress,
hosts `argocd.localhost`, `headlamp.localhost`, `shop.localhost`. ingress-nginx was ruled out (archived in
March 2026). `dev-up.ps1` now checks each host through the ALB and prints the URLs.

## Findings

- My first spike commands failed because I exported test credentials into the shell that `kubectl` also
  used: the kubeconfig's auth helper picked them up and returned Unauthorized. Run `kubectl` before, or apart
  from, credential overrides.
- Docker briefly stopped answering during testing (a `docker ps` hung for two minutes), which dropped the
  owner's port-forward. Free memory was low (about 2 GB of 14 GB). Two test containers of mine were left
  behind and were removed.
- Argo CD reports an Ingress Progressing until it has a load-balancer address; Traefik with a NodePort
  service has none, so the chart is told to publish `localhost` as the Ingress address.

## Verification

`tofu validate` and `tofu plan` pass for both roots (the ALB module: 4 to add; the cluster root: relay and
Traefik apps). `dev-up.ps1` parses on Windows PowerShell 5.1 and PowerShell 7. The ALB data path was proved with
the spike. Not yet run: the apply on the long-lived Floci, a real webhook delivery, and the browser check.

## Next

The owner runs `.\scripts\dev-up.ps1 -Revision <this branch>`. Then a real delivery (GitHub can send a test
event to the hook) and the browser check of the three URLs; then the rollback drill.
