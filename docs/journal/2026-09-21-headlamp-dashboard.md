# 2026-09-21: A read-only cluster dashboard (Headlamp)

**Phase:** Phase 1, GitOps delivery (operator tooling)
**Related ADRs:** [ADR-0013](../../adr/0013-gitops-with-argo-cd-on-long-lived-aws.md), decision 8

## What happened

Argo CD reached Synced and Healthy on the long-lived cluster. The owner then asked for a simple
web-based dashboard for cluster status and information. The candidates were checked against their
repositories rather than from memory: the Kubernetes Dashboard is archived (January 2026) and points
to Headlamp; Skooner has had no commits since June 2024; Portainer is container-first with
Kubernetes as a side feature; Lens and k9s are desktop and terminal tools. Headlamp is a
`kubernetes-sigs` (SIG UI) project, Apache-2.0, actively maintained (v0.45.0), with an official Helm
chart.

It is deployed by Argo CD as a second `Application`. To allow that, the `argocd` module now takes a
map of Applications, each either a git path or a Helm chart source, instead of one hard-coded app.

## Why

The chart's default binds Headlamp's service account to `cluster-admin`. A dashboard needs to show
status, not change anything, so the binding is overridden to the built-in `view` role. Access is a
port-forward plus a service-account token; there is no ingress.

## Verification

`tofu validate` passes and `tofu plan` shows an in-place update of the applications release (the
boutique application unchanged, Headlamp added). `dev-up.ps1` parses on Windows PowerShell 5.1 and
PowerShell 7 and now prints how to reach both dashboards. The owner confirms the apply and the login.

## Next

The bump workflow (bot PR after each build), then the CI check that Argo syncs a PR's commit, then
the rollback drill. `view` does not include custom resources, so Argo's Applications are not visible in
Headlamp; a small aggregated role could add that if it is wanted.
