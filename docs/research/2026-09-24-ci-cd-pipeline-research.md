# Research: what a good GitHub Actions CI/CD pipeline looks like (2026)

**Date:** 2026-09-24 to 2026-10-01. **Feeds:** [D24](../../PLAN.md#d24) and the
[pipeline guide](../guides/ci-cd-pipeline-standard.md). **Evidence labels:** *primary* (the vendor or standards body),
*secondary* (security firms, blogs), *tested* (run in this repository).

## 1. Questions

1. What do GitHub, OpenSSF, SLSA and DORA recommend for CI/CD on GitHub Actions?
2. What attacks on CI happened recently, and what stopped them?
3. Which tools fit this project (containers, OpenTofu, Kubernetes manifests, GitOps)?
4. Where does the current pipeline fall short?

## 2. Findings

### 2.1 Security baseline (GitHub, primary)

From GitHub's [secure-use reference](https://docs.github.com/en/actions/reference/security/secure-use): set the default
`GITHUB_TOKEN` to read-only and grant per job; pin third-party actions to a full commit SHA ("the only immutable approach");
pass untrusted values to scripts through environment variables, never `${{ }}` inside `run:`; avoid `pull_request_target`
and `workflow_run`; use OIDC instead of stored cloud keys; put `.github/workflows` under `CODEOWNERS`; use Dependabot for
actions; run OpenSSF Scorecard. Self-hosted runners should almost never serve public repositories.

### 2.2 Recent attacks (secondary, with primary advisories)

- **tj-actions/changed-files, March 2025** ([CISA](https://www.cisa.gov/news-events/alerts/2025/03/18/supply-chain-compromise-third-party-tj-actionschanged-files-cve-2025-30066-and-reviewdogaction)):
  a stolen token let an attacker repoint tags at code that printed runner secrets into public logs; about 23,000 repositories.
- **Trivy / TeamPCP, March 2026** ([GHSA-69fq-xp46-6x23](https://github.com/aquasecurity/trivy/security/advisories/GHSA-69fq-xp46-6x23),
  [Wiz](https://www.wiz.io/blog/trivy-compromised-teampcp-supply-chain-attack)): 76 of 77 `trivy-action` tags and all
  `setup-trivy` tags force-pushed to a credential stealer. Releases protected by GitHub's immutable releases were unaffected.
- **Lesson both times:** a tag is a pointer anyone with write access can move. A full commit SHA cannot be moved. Pinning
  alone is not enough without updates, and updates are safer with a delay (a cooldown).
- **This repository (tested):** the pinned `trivy-action` commit `ed142fd` is v0.36.0, published 2026-04-22 after the
  incident, verified and immutable. Not exposed. But the Trivy it ran by default, v0.70.0, is affected by
  GHSA-mcj4-mphf-j9ff (high, fixed in 0.71.1) and two medium advisories.

### 2.3 Supply-chain standards (primary)

- **SLSA** ([levels](https://slsa.dev/spec/v1.0/levels)): Build L1 provenance exists; L2 signed provenance from a hosted
  build platform (protects against tampering after the build); L3 hardened builds where runs cannot influence each other.
- **GitHub artifact attestations** ([docs](https://docs.github.com/en/actions/concepts/security/artifact-attestations),
  [`actions/attest`](https://github.com/actions/attest)): free on public repositories, Sigstore-signed, give SLSA Build
  L2; a reusable workflow shared across repositories is GitHub's route to L3. `actions/attest` v4 creates SLSA provenance by
  default and an SBOM attestation with `sbom-path`; `attest-build-provenance` is now a wrapper around it. Verified with
  `gh attestation verify oci://<image>@<digest> --repo <owner/repo>`.
- **OpenSSF Scorecard** ([checks](https://github.com/ossf/scorecard/blob/main/docs/checks.md)): 20 checks, including
  Token-Permissions, Pinned-Dependencies, Dangerous-Workflow, Dependency-Update-Tool, SAST, Signed-Releases, SBOM and
  Branch-Protection. Publishing results requires a restricted workflow shape.

### 2.4 Delivery practice (DORA, primary)

From [DORA's CI capability](https://dora.dev/capabilities/continuous-integration/): every commit builds; tests run in a few
minutes, ten at most; trunk-based development with merges at least daily; a broken build is fixed before other work; build
status visible to the team. Pitfalls: manual steps, slow tests, long-lived branches.

### 2.5 Tools (primary docs, tested here)

| Need | Tool | Note |
|---|---|---|
| Workflow security lint | [zizmor](https://docs.zizmor.sh/audits/) v1.30.1 | 38 audits; online mode adds impostor-commit and known-vulnerable-action checks. Audited by Trail of Bits in May 2026. |
| Workflow syntax lint | actionlint v1.7.12 | Already used. Does not yet accept GitHub's July 2026 `$/` self-repository syntax. |
| Image scan and SBOM | Trivy v0.74.0 | One tool for vulnerabilities, misconfigurations (IaC) and CycloneDX SBOMs. tfsec was merged into Trivy. |
| IaC misconfiguration | `trivy config` | Covers OpenTofu (same HCL). Checkov is deeper but a second tool. |
| Manifest validation | [kubeconform](https://github.com/yannh/kubeconform) v0.8.0 | Successor to kubeval; schemas for Kubernetes 1.36 available. |
| Dependency updates | Dependabot | Supports `github-actions`, `docker-compose`, `opentofu`; `cooldown` delays adoption of new releases. |
| Provenance and SBOM | `actions/attest` v4 | See 2.3. |

### 2.6 Platform limits (primary)

- **Merge queue** is available only for repositories owned by an organization (any plan, public repositories), not for a
  personal account ([GitHub docs](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue);
  community reports confirm the personal-account limit).
- **Rulesets** are available for public repositories on the free plan, layered with classic branch protection.
- **`$/` self-repository syntax** ([GitHub changelog, 2026-07-30](https://github.blog/changelog/2026-07-30-reference-same-repository-actions-with-self-repository-syntax/)):
  `uses: $/path` resolves to the same repository at the running commit, needing runner 2.336.0+.

## 3. The current pipeline, measured against this

| Finding | Severity | Source |
|---|---|---|
| Same-repo PRs push images; `main` reuses an existing content tag, so a PR that changes only the build can supply the image that gets deployed | high (design) | review |
| `bump-images` uses the `workflow_run` trigger (guarded, not exploitable today) | high (zizmor) | tested |
| Checkouts keep the token on disk (`artipacked`) in 8 places | medium (zizmor) | tested |
| Trivy v0.70.0 with a high advisory; no tool updates any pin | high | tested |
| Image scan never fails (report-only): 7 fixable criticals today, nothing stops an eighth | medium | tested |
| No provenance, no SBOM; pins by tag, which GHCR allows to move | medium | review |
| No manifest validation; a bad manifest is found by Argo CD after merge | medium | review |
| Workflow-level `contents: read` instead of `{}`; some jobs without timeouts | low | review |
| Good already: SHA pins, gate jobs, path filtering with always-on required checks, concurrency, OIDC design, pre-gate shared with CI, secret scanning over full history | | review |

## 4. Verification of the new gates (tested, 2026-10-01)

- `kubeconform` rejected a planted Deployment with a string `replicas` and a misspelt field; it did not catch an invalid
  `imagePullPolicy` value (a limit of the schemas).
- `zizmor` flagged a planted `issue_comment` workflow echoing the comment body as a high `template-injection`.
- Trivy gate on the deployed `currencyservice`: fails with no baseline; fails with an expired baseline; and, with the first
  draft of the baseline (taken from older Security-tab results), still failed on `CVE-2026-59873`, a critical that appeared
  since. The baseline was rebuilt from a fresh scan of all 12 images with Trivy v0.74.0; all 12 then pass.
- After the rewrite: `zizmor` 0 findings (from 1 high, 8 medium), `actionlint` clean, all `scripts/check` checks pass.
