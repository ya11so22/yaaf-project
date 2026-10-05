# Handoff: picking the project up on the Mac

Written 2026-10-03 on the Windows PC, at the end of the Windows era (tag `archive/windows-era`). Read this, then
`CLAUDE.md` (working rules), `README.md`, `CONTEXT.md` (glossary) and `adr/README.md` (current decisions). Delete or
rewrite this file once the Mac setup is done; from then on `docs/milestones.md` and `docs/journal/` carry the status.

## What the project is

A portfolio and learning project for a DevOps engineer moving towards platform and AWS Solutions Architect roles: a
fictional card-payments retailer moves its storefront (Google's Online Boutique, vendored in `app/`) to AWS, and the
repository is that engagement, designed, built, operated and broken on purpose, with each decision recorded. The AWS is
**Floci**, a free local emulator; nothing billable is ever created on real AWS. Details: ADR-0021, ADR-0022.

## State on 2026-10-03

| Area | State | Evidence |
|---|---|---|
| Local AWS (Floci, three OpenTofu roots, EKS on k3s, ALB, Argo CD, portal, EC2 workstation) | built and working on Windows | verified on Floci; never run on the Mac |
| Delivery (GitHub Actions to GHCR, GitOps with Argo CD, bot PR pins images) | working | Phase 1 end-to-end run and failure drill (`docs/postmortems/`) |
| Pipeline standard (ADR-0024: provenance, SBOM, digest pins, scan ratchet, zizmor, kubeconform, Scorecard, Dependabot) | merged in PR #26 | first `main` run (2026-10-03): all 12 images passed the scan gate, the `pins` job wrote `tag@digest` pins and the bot PR (#27) merged; a squash-only bug in auto-merge was found and fixed (#29). **Not yet exercised:** publishing and attestations, because every image was reused (no service changed) |
| Architecture track (`docs/architecture/`) | scenario chosen, nothing else written | |
| Phase 2 (operate it), Phase 3 (assistant replatform) | not started | `docs/milestones.md` |

## Removed in the move (all readable at tag `archive/windows-era`)

- `scripts/dev-up.ps1`, `scripts/dev-down.ps1`: replaced by guidelines in [`docs/mac-migration.md`](docs/mac-migration.md).
- `adr/archive/` (ADR-0001 to 0019 except 0005, 0006, 0009): superseded by ADR-0021 to 0023. Numbers are not reused.
- `docs/journal/` entries 2026-09-16 to 2026-10-01: the history; this file and the milestones carry what still matters.
- `CONTRIBUTING.md`, `docs/agents/`: folded into `CLAUDE.md`.
- `.claude/skills/` (vendored assistant skills) and `.actrc`: install the skills at user level (`docs/mac-migration.md`).

## Next, in order

*Updated 2026-10-04. The order below follows [`docs/milestones.md`](docs/milestones.md); the decisions are ADR-0025 to 0029.*

1. ~~**Set up the Mac and rebuild the task interface.**~~ Done: `mise.toml` and `.mise/tasks/` ([ADR-0025](adr/0025-tool-versions-and-tasks-in-mise.md)),
   on the project's own Colima VM. `up` builds everything, and with item 3 the shop works.
2. ~~**App-of-apps and Gateway API**~~ Done 2026-10-05 ([ADR-0026](adr/0026-argo-cd-app-of-apps.md), [ADR-0029](adr/0029-gateway-api-for-ingress.md),
   [guide](docs/guides/gateway-api.md)).
3. ~~**arm64-only images**~~ Done 2026-10-05 ([ADR-0027](adr/0027-arm64-only-app-images.md)), including the first publish and
   attestation (verified with `gh attestation verify oci://ghcr.io/ya11so22/yaaf-project/<service>@<digest> --repo ya11so22/yaaf-project`;
   add `--predicate-type https://cyclonedx.org/bom` for the SBOM). Dependabot opens grouped PRs weekly; merge them when green.
4. **Finish the Floci upstream fix** (below), then ask the owner before opening anything upstream.
5. Then Phase 1 close-out (threat model, pre-merge deploy check, demo), the scenario library ([ADR-0028](adr/0028-scenario-library.md)),
   Phase 2, and the architecture track (`00-requirements.md` first).

## The Floci CloudFront fix (not sent upstream)

Bug: Floci stores tags given to `CreateDistributionWithTags` under `distribution/<id>` but reads them by ARN, and its
controller reads the valueless `?WithTags` flag as null, so tags are lost twice over. Details:
`docs/research/2026-09-24-floci-upstream-findings.md` (F1).

Done: patch with the fix and four tests, `docs/research/patches/floci-cloudfront-tags-by-arn.patch` (against
floci-io/floci `main` at `4e3bbe5`). The tests failed on unchanged code for the right reason; the 47 service tests passed
with the first half of the fix, which is how the second cause was found.

Not done (Docker kept stalling on Windows): the full CloudFront regression run with both halves, and an end-to-end check
of a Floci image built from the fix. To finish on the Mac:

```bash
git clone https://github.com/floci-io/floci.git && cd floci
git apply /path/to/yaaf-project/docs/research/patches/floci-cloudfront-tags-by-arn.patch   # rebase if main moved
./mvnw test -Dtest='CloudFront*,CloudFormationCloudFront*'   # needs Java 25; or the maven:3.9-eclipse-temurin-25 image
docker build -f docker/Dockerfile -t floci:cf-fix .          # then run the static-site module against it:
# apply, then `tofu plan -detailed-exitcode` must exit 0 (no drift) with provider default_tags set
```

The owner's rule: **do not open the upstream PR until the fix is proven end to end, and ask first.** Floci's
`CONTRIBUTING.md`: Conventional Commit PR title (`fix(cloudfront): ...`), and **no `Co-Authored-By` trailers for AI tools**
(CI rejects them).

## Open decisions for the owner

- ADR-0020 (real AWS only for free identity services): proposed, now optional after the IAM drill.
- Keep or drop the ECR module and GitHub OIDC roles (applied on Floci, unused by CI; ADR-0023).
- Whether the learning extras (EC2 workstation, portal, Headlamp, IAM drill) stay in the default `up` or move to an
  opt-in root.
- Filing the other upstream findings (Floci F2 to F5 as issues; the floci-dash WebSocket origin issue privately).
