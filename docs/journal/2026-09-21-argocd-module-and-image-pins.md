# 2026-09-21: Argo CD module and committed image pins

**Phase:** Phase 1, GitOps delivery
**Related ADRs:** [ADR-0013](../../adr/0013-gitops-with-argo-cd-on-long-lived-aws.md), [ADR-0011](../../adr/0011-cd-image-identity-scope-and-state.md), [ADR-0014](../../adr/0014-operating-the-long-lived-aws.md)

## What happened

Three pieces of ADR-0013 landed:

- **Committed image pins.** `deploy/dev/kustomization.yaml` carries a marked block of `images:`
  entries, one per service, each pinned to `ghcr.io/ya11so22/yaaf-project/<service>:content-<hash>`.
  `.github/scripts/bump-images.sh` rewrites the block; `--verify` fails if a tag is missing from GHCR.
  This replaces render-time pinning, so `render-manifests.sh` and its test were removed. A new test
  checks idempotency, that the markers are respected, and that the committed pins render to our
  registry only. The interim push-based `deploy.yml` now applies `kubectl kustomize deploy/dev`.
- **The `argocd` module** (`infra/modules/argocd`): the official chart, pinned (10.9.2, Argo CD
  v3.5.3), with Dex and notifications off, plus the `Application` for `deploy/dev` created through
  the chart's `extraObjects` so it lands after the CRDs in the same release. Sync is automated with
  prune and self-heal.
- **A second root, `infra/environments/floci-cluster`**, because the Helm provider needs an existing
  cluster to connect to. It uses Helm provider 3.3.0, whose configuration is an attribute
  (`kubernetes = { ... }`) rather than the older block. `scripts/dev-up.ps1` applies it after the
  cluster is ready (`-Revision` selects the git revision Argo tracks) and reports Argo's view.

ADR-0013 was corrected: the Application is created by OpenTofu at bootstrap, not kept in
`deploy/argocd/`, because the tracked revision differs by environment.

## Finding: the Application cannot share the Argo CD release

The first apply failed with `no matches for kind "Application" in version "argoproj.io/v1alpha1":
ensure CRDs are installed first`. Helm cannot create a custom resource in the same release that
installs its CRD, so creating the Application through the chart's `extraObjects` does not work. The
module now uses two releases in order: `argo-cd` (which installs the CRDs), then the companion
`argocd-apps` chart (2.0.5), which Argo's project publishes for this, with `depends_on`. The failed
attempt left nothing behind (no state, namespace or CRDs), so the re-run started clean.

## Verification

`tofu validate` passes for the new module and root; `tofu plan` fetched the real chart and showed the
release would be created; `scripts/check` passes, including the new pin tests; the tags in the pins
were verified against GHCR with `--verify`. Not yet confirmed: the apply on the long-lived Floci, and
Argo CD reaching Synced and Healthy. Automated applies are blocked for me, so the owner runs
`.\scripts\dev-up.ps1 -Revision docs/adr-0013-gitops-argocd` (the branch that holds these pins).

## Next

Confirm that run, then the bump workflow (bot PR after a build), the CI check that Argo syncs a PR's
commit on a throwaway Floci (replacing `deploy.yml`), and the rollback drill.
