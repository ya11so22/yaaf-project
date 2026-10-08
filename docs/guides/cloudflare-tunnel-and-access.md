# Guide: publishing a private service with a tunnel and a login

**Related:** `PLAN.md` D33, D34, D38; `.github/workflows/edge-check.yml`
**Evidence:** designed. Becomes *verified* once `edge-check` passes against the real domain.

## The idea

The demo environment runs on a GitHub runner that accepts **no inbound connections**: nobody on the internet can reach
it, and that is a good thing. To show it anyway, a small agent on the runner dials **out** to Cloudflare and holds the
connection open. Cloudflare then sends visitors of `shop.yaafsome.fyi` down that connection. This is a **tunnel**: no
open port, no public IP, no firewall rule, and it vanishes when the runner does.

A public URL for an operator tool (Argo CD, Grafana) is still a risk, so Cloudflare puts a **login in front of it**
before any request reaches the tunnel. That is **Access**, a small "zero trust" gateway: each request must carry a proof of
who you are, rather than coming from a trusted network. The shop stays open, as a storefront would.

## How it works here

```
visitor ─https─▶ Cloudflare edge ──(Access login for argocd/grafana)──▶ tunnel ◀─outbound─ cloudflared on the runner
                                                                                                │
                                                                       localhost:18080 (ALB → Traefik → HTTPRoute)
```

| Hostname | Goes to | Access |
|---|---|---|
| `yaafsome.fyi` | The showcase on Vercel (stage 7) | none |
| `check.yaafsome.fyi` | A test page `edge-check` serves on the runner | none |
| `shop.yaafsome.fyi` | The shop, while a demo run is up (stage 4) | none |
| `argocd.yaafsome.fyi`, `grafana.yaafsome.fyi` | The operator UIs, while a demo run is up | email one-time code |

The tunnel is **managed in the Cloudflare dashboard** (D38): the hostnames, where each one goes, and the Access rules
live there, and the runner only needs one secret, the tunnel token. `edge-check` proves the whole path: it serves a
page containing its own run number, publishes it through the tunnel, fetches it back from the internet, and checks that
the operator hostnames redirect to the Access login while the shop does not.

### One-time setup (the owner, in the Cloudflare dashboard)

1. **Zero Trust.** Open *Zero Trust* and pick a team name (it becomes `<team>.cloudflareaccess.com`) and the **Free**
   plan. Watch out: if it asks for a card, stop there and say so in the chat; the project rule is to ask first.
2. **Login method.** *Settings → Authentication*: keep **One-time PIN** (a code sent by email; no other identity provider
   needed).
3. **The tunnel.** *Networks → Tunnels → Create a tunnel*, type **Cloudflared**, name `yaaf-demo`. On the install page,
   copy the **token** (the long string after `--token`) and do not run the install command anywhere.
4. **Public hostnames** on that tunnel (*Public Hostname → Add*), all in the zone `yaafsome.fyi`:

   | Subdomain | Service | HTTP Host Header (under *Additional application settings → HTTP Settings*) |
   |---|---|---|
   | `check` | `http://127.0.0.1:8080` | (leave empty) |
   | `shop` | `http://127.0.0.1:18080` | `shop.localhost` |
   | `argocd` | `http://127.0.0.1:18080` | `argocd.localhost` |
   | `grafana` | `http://127.0.0.1:18080` | `grafana.localhost` |

   The Host header makes the cluster's existing routes match (they route by `*.localhost`, D29), so nothing in
   `deploy/` changes yet. Each row also creates the DNS record for you.
5. **Access application.** *Access → Applications → Add → Self-hosted*, name `yaaf operator UIs`, hostnames
   `argocd.yaafsome.fyi` and `grafana.yaafsome.fyi`. One policy: **Allow**, *Emails*, your own address (add others to
   invite them for a demo). Session duration 24 hours.
6. **The secret.** In GitHub: *Settings → Environments → New environment* `demo`, then *Add environment secret*
   `CLOUDFLARE_TUNNEL_TOKEN` with the token from step 3.
7. **Prove it.** *Actions → edge-check → Run workflow.* It should end green with "check.yaafsome.fyi serves this run's
   page", two "behind Access" lines and "shop.yaafsome.fyi: public".

## Why this way

- **Quick tunnel** (`*.trycloudflare.com`): no account, but a random URL per run and no Access in front. It was the
  plan until the domain existed (D33's first version).
- **Opening a port** on a host: needs a long-lived machine with a public IP and a firewall. The project has neither, on
  purpose (D31).
- **The edge as OpenTofu** (Cloudflare provider): a stronger infrastructure-as-code story, but it needs a scoped API
  token and somewhere permanent for state, which the ephemeral Floci is not. Kept as a possible later step.

## Watch out for

- **The token is a password for the tunnel.** Anyone holding it can attach their own machine and receive the traffic for
  every hostname above. It lives only in the `demo` environment secret; if it leaks, *rotate* it on the tunnel's page.
- **Access protects only the hostnames it lists.** A new operator UI needs a new tunnel hostname *and* adding to the
  Access application; `edge-check` fails if Argo CD or Grafana answers without the login, which is the point of it.
- **A fresh domain takes a while to resolve.** `yaafsome.fyi` was registered on 2026-10-08 and the `.fyi` registry had not
  published it an hour later; until it does, every lookup says "no such domain" (NXDOMAIN). *Hit by this project.*
- **Use `127.0.0.1`, not `localhost`, as the service address.** The origins listen on IPv4 loopback only; if
  `localhost` resolves to `::1` first, cloudflared gets connection refused and visitors see a 502.
- **One tunnel, one runner at a time.** Every run that holds the token adds a connector to the same tunnel, and
  Cloudflare spreads requests across them, so two runs at once answer each other's hostnames with 502s. The workflows
  share one concurrency group, `yaaf-demo-tunnel`.
- **Free Universal SSL covers one level of subdomain** (`shop.yaafsome.fyi`, not `shop.demo.yaafsome.fyi`). That is why
  the hostnames sit directly under the apex.

## Check yourself

<details><summary>How does a visitor reach a service on a machine that accepts no inbound connections?</summary>

The machine makes an outbound connection to Cloudflare and keeps it open; Cloudflare forwards requests for the
hostname down that existing connection. Nothing listens on the internet.

</details>

<details><summary>Why is Argo CD behind Access but the shop is not?</summary>

The shop is the customer-facing product and is meant to be public. Argo CD shows (and with the wrong account could
change) how the platform is deployed, so it needs to know who is asking before the request ever reaches it.

</details>

<details><summary>How do you know the login really sits in front of Argo CD?</summary>

`edge-check` asks for the page without logging in and requires a redirect to the Cloudflare Access login; it also
requires that the shop is *not* redirected, so a rule that covered everything would fail too.

</details>
