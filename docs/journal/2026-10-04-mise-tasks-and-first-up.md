# 2026-10-04: mise tasks, and the first `up` on the Mac

**Phase:** cross-cutting (the Mac era, step 2 of the order in `docs/milestones.md`)
**Related ADRs:** [0025](../../adr/0025-tool-versions-and-tasks-in-mise.md), [0022](../../adr/0022-the-local-aws-environment.md) (amended), [0027](../../adr/0027-arm64-only-app-images.md)

## What happened

- Built the task interface: `mise.toml` (nine tools pinned, `mise.lock` committed, shared values, isolation), and the tasks
  `up`, `down`, `reset` (`.mise/tasks/`) and `check`. `scripts/check` now runs the locked binaries with no Docker, and
  `check.yml` and `infra.yml` install them with `jdx/mise-action`.
- Fixed three macOS-only bugs in the bump scripts first (PR 34): `awk -v` with newlines, an empty array under `set -u` in bash 3.2,
  and GNU-only `sed`.
- Ran `mise run up` on the project's own Colima VM five times and fixed what each run showed (below).
- The default Colima VM, which runs other software, was stopped by a separate session during this work; it was restarted by the
  owner. From then on every colima command here names the `yaaf` profile, and `mise.toml` sets `COLIMA_PROFILE` and
  `DOCKER_CONTEXT` so a stray command cannot reach the default VM.

## Why

ADR-0025: one file for versions, shared values and tasks, so nothing drifts and CI runs what the developer runs. The isolation
(`.aws/`, `.kube/`, the project's own VM) follows from the owner's zero-accident rule and from the shared-VM incident above.

## Verification

*Verified on Floci, on the Mac:*

- `scripts/check` passes in full, including through the git hook path. One planted fault per checker, each caught: `tofu fmt`,
  actionlint, kubeconform, zizmor (a third-party action pinned by tag) and gitleaks (a random-looking token). Two first plants
  passed for understood reasons (zizmor allows GitHub's own `actions/*` by tag; gitleaks ignores AWS's `EXAMPLE` keys).
- `up` from nothing builds the whole environment: 4 + 74 + 2 resources, the cluster Ready, Argo CD installed, and the portal,
  floci-dash, Argo CD and Headlamp answering with their own content.
- `down` takes about 17 seconds and stops only the `yaaf` VM; `up` continues from the kept data.

What the five runs found:

1. **`AWS_PROFILE=floci` in `mise.toml` broke the first run.** The AWS provider fails on a named profile that does not exist yet
   (`up` writes it after the foundation root). Removed; commands name `--profile floci`.
2. **Port 8080 belongs to the owner's qBittorrent.** Every `*.localhost:8080` request returned that page. The ingress listener is
   now published on 18080 (`INGRESS_PORT`, set once in `mise.toml`).
3. **The URL check passed an error page.** The shop returned HTTP 500 and the page said "Online Boutique", so a text-only check
   was satisfied. The check now needs HTTP 200 and the text; it correctly fails for the shop.
4. **Four app pods crash-loop on the arm64 node** (`cartservice`, `currencyservice`, `paymentservice`, `recommendationservice`),
   so the shop answers 500 and Argo CD reports `online-boutique-dev` Progressing. Causes: the amd64 images run under emulation,
   and Google's probes (`delay=0s`, 1 s timeout) kill slow starters; `paymentservice` was `OOMKilled` at its 128 Mi limit; `cartservice`
   could not create the .NET runtime (`HRESULT 0x8007000E`, out of memory). The other six services run. This is the case for
   ADR-0027, not a fault in `up`.
5. **Quirk Q1 is intermittent, and not only after abrupt stops.** After one graceful `down` and `up` the cluster never became
   Ready (3 minutes), and the repair step rebuilt it and Argo CD restored the workloads. After a second identical cycle it was Ready
   in 12 seconds. The repair step now prints the dead container's state and logs, so the next occurrence leaves evidence.

## Learn

- A health check must test the thing that matters: text on a page is not health (an error page can name the product).
- Isolation by default beats care: setting `COLIMA_PROFILE` and the AWS and kube config paths in one place makes the safe thing the
  only thing the tools can do.
- Two services can silently share a loopback port when one is bound by a VM's port forward; check the port before you publish it.

## Next

Step 3 of the order: app-of-apps and Gateway API (with its guide). Then the arm64 pipeline, which is what fixes the four crashing
pods. `HANDOFF.md` is updated to what remains (the Mac setup is done); it stays until the Floci upstream fix, which only it describes, is finished.
