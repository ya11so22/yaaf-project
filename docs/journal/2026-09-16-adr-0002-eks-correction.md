# 2026-09-16: Corrected ADR-0002's EKS-fidelity claim against current Floci docs

**Phase:** Pre-Phase-1 (setup)
**Related ADRs:** [ADR-0002](../../adr/archive/0002-aws-emulation-strategy.md)

## What happened

Before starting real infra work, did a documentation pass on Floci and the other tools the
project depends on, since Floci is young/actively developed and the ADRs were written from a
point-in-time understanding of it. Fetched Floci's current GitHub README and cross-checked the
LocalStack-sunset context the original ADR alluded to.

Found one factual correction: ADR-0002 described Floci's EKS support as `"mock + k3s"`. Current
docs are more specific — EKS emulation runs an actual `rancher/k3s` container with a live
Kubernetes API server behind the EKS-shaped control-plane API. That's genuine k8s API behavior,
not a shallow mock; the real gap is narrower than the original wording implied (IRSA behavior,
real VPC networking edge cases, managed node group quirks — not the control plane itself).

Edited ADR-0002's option-2 con to reflect this without changing the decision itself.

## Why

An ADR is only useful as a "why is the Terraform shaped this way" defense if its factual claims
hold up under questioning. Overstating the emulation gap would have undersold what Floci's EKS
support actually gets you, and understating it (in the other direction) would have set the
wrong expectation for the real-AWS milestone validation step. Confirmed via primary source
(Floci's own repo) rather than relying on point-in-time model knowledge, given how fast the
project moves.

Also confirmed, as useful context (not an ADR change): LocalStack Community was sunset for real
— auth-token-gated since March 23, 2026, grace period ended April 6, 2026. This makes ADR-0002's
"Floci as the free alternative" framing more relevant now than when it was written, not less.

## Verification

Cross-referenced Floci's GitHub README directly (not just secondary summaries) and a separate
search confirming the LocalStack sunset timeline independently, since that claim is unusual
enough to be worth double-checking before repeating it in project docs.

## Next

No action item — this was a correction pass, not new work. Worth repeating a similar spot-check
before any milestone that leans hard on a specific Floci capability, since it's still actively
developed.
