# ADR-0023: Build and delivery

**Status:** accepted (consolidates and supersedes ADR-0007, 0008, 0011, 0013 and 0015, now in [`archive/`](archive/))
**Date:** 2026-09-24

## Context

How code becomes a running app was decided in steps: split CI pipelines and GHCR (0007), push-based CD (0008),
content-hash image tags (0011), then GitOps with Argo CD replacing push-based CD (0013) and a webhook relay to
make Argo CD react faster (0015). The push-based `deploy.yml` stayed behind as an interim check and proved fragile
(rapid pushes cancelled it). This ADR states the current pipeline in one place.

## Options considered

- **Delivery:** push from CI into the cluster (what 0008 built; a script, with no drift correction); **pull-based
  GitOps with Argo CD** (chosen: reconciles from git, heals drift, and rollback is a git operation).
- **Image identity:** a moving `main` tag (not reproducible); build everything on every change (slow); **a content
  hash of each service's source** (chosen: unchanged services keep their tag, so every pin points at an image that
  exists).
- **Registry:** ECR (in the emulator it vanishes with the runner; on real AWS it costs money); **GHCR** (chosen:
  free for a public repository, persistent, no AWS in the build path).
- **Getting merges to Argo CD quickly:** a GitHub webhook through the smee.io relay (what 0015 built; removed
  2026-09-24, see below); a public tunnel (exposes Argo CD); **Argo CD polling every 60 seconds** (chosen).

## Decision

1. **Four CI workflows on GitHub Actions,** third-party actions pinned to commit SHAs:
   - `build`: finds the changed services under `app/src`, builds each for amd64, scans with Trivy (report-only),
     and pushes to GHCR with a commit tag and a `content-<hash>` tag (the git tree hash of the service's folder).
   - `infra`: `fmt`, `validate` and `plan`, then a smoke test that applies the dev roots to a fresh Floci, requires a
     no-changes re-plan, and destroys it.
   - `check`: the shared pre-gate script (ADR-0009).
   - `cleanup`: keeps the newest 10 versions of each GHCR package.
   `build`, `infra` and `check` are always-running gate jobs, required by branch protection on `main`.
2. **Delivery is GitOps.** Argo CD, installed by OpenTofu (`cluster` root, ADR-0022), reconciles the app, Traefik,
   Headlamp and the ingress rules from git with automated sync, prune and self-heal. Nothing pushes into the cluster.
3. **Image pins live in git** (`deploy/dev/kustomization.yaml`). After each successful build on `main`, the
   `bump-images` workflow opens one pull request as a GitHub App bot (a PR made with the default token would not
   trigger the required checks) and enables auto-merge.
4. **Rollback is reverting the source change, not the pin.** The bump workflow recomputes pins from the source after
   every build, so a pin-only revert is undone within a minute (found in the Phase 1 failure exercise). Reverting the
   source restores the earlier content tag, which is already built.
5. **Argo CD polls git every 60 seconds** instead of the default three minutes. The smee.io webhook relay is removed:
   smee re-serialises the body, so GitHub's signature can never verify; it depended on a community service; and
   `dev-up` had to rewrite the repository's webhook on every start. On real AWS, a load balancer or API Gateway in
   front of Argo CD would receive signed webhooks directly; that stays a design note.
6. **Deploy scope:** the ten Online Boutique services and `redis-cart`, without the load generator; the shopping
   assistant joins in Phase 3 (ADR-0021).
7. **A read-only cluster UI:** Headlamp, from its official chart, bound to a read-only `headlamp-viewer` role that
   excludes secrets, with no login, reachable only on loopback.
8. **The pre-merge deploy check** (planned, Phase 1 close-out) replaces the removed `deploy.yml`: apply the dev roots
   to a throwaway Floci in the pull request, install Argo CD, point it at the PR's commit and wait for `Synced` and
   `Healthy`.

## Rationale

Pull-based delivery is the pattern platform teams run, and it makes the desired state reviewable in git.
Content-hash tags keep path-filtered builds and reproducible deploys compatible. Polling at 60 seconds gets most of
the webhook's benefit with none of its weaknesses; the webhook story (and the signature finding) remains in the
archive as a learning.

## Consequences / trade-offs accepted

- A merge reaches the cluster in up to about a minute, not seconds.
- Until the pre-merge check exists, a bad manifest is caught only after merge, by Argo CD reporting it Degraded.
- The bot's GitHub App key is a repository secret to protect; the bot can only open pull requests, which branch
  protection still gates.
- Trivy stays report-only until the upstream images' known findings are triaged.
- The GitHub webhook that `dev-up` registered for smee is left on the repository until the owner deletes it.
