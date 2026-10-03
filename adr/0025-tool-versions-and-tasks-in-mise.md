# ADR-0025: One `mise.toml` for tool versions, environment values and tasks

**Status:** accepted (amends [ADR-0009](0009-local-pre-gate.md): the checks run installed binaries, not Docker images; refines [ADR-0024](0024-ci-cd-pipeline-standard.md): the Trivy scan runs the locked `trivy` binary, not `trivy-action`)
**Date:** 2026-10-03
**Evidence:** designed, with parts tested on the owner's Mac (mise 2026.9.16). All nine tools below resolve through mise's `aqua` backend, and `mise lock` for `macos-arm64`, `linux-arm64` and `linux-x64` wrote 27 entries (9 tools by 3 platforms). **Eight of the nine carry a SHA-256 checksum; `awscli` does not**, because AWS publishes none beside its download, so it is locked by version and URL only. Not yet run: `mise install --locked` and the whole `check` in CI.

## Context

The move to the Mac exposed that versions are pinned in places that only memory keeps in step
([review](../docs/research/2026-10-03-architecture-review.md), section 2.2):

- OpenTofu `1.12.6` appears only in `infra.yml`; the foundation and cluster roots say `>= 1.10`.
- The checkers (actionlint, gitleaks, zizmor, kubeconform) are Docker image digests inside `scripts/check`, one
  `docker run` each, with Windows path handling.
- Trivy is `v0.74.0` in the build workflow and unset in `rescan.yml`, so the weekly rescan and the build gate can run
  different scanners and disagree.
- The Kubernetes minor (1.36) is written in `compose.yaml` (as a k3s image), `scripts/check` and `modules/eks-cluster`.
- `kubectl`, `awscli` and `gh` have no pin at all.

The Windows operator scripts were also removed; the task interface (`up`, `down`, `reset`, `check`) has to be rebuilt
([`docs/mac-migration.md`](../docs/mac-migration.md)), and the owner's rule is minimal scripts with tools doing the work.

## Options considered

1. **Leave the pins where they are.** No new tool; the drift above stays, and `check` keeps needing Docker.
2. **`just` or Task for the tasks, and `aqua` or `asdf` for versions.** Two tools for one job.
3. **Nix.** The strongest reproducibility, and a large new concept to learn and operate for a project of this size.
4. **`mise` for versions, environment values and tasks, with a committed lockfile** (chosen). One file. Its `aqua` backend
   covers every tool this project needs, and `mise.lock` records versions, URLs and checksums.

## Decision

1. **`mise.toml` at the repository root pins** `opentofu`, `kubectl`, `awscli`, `gh`, `actionlint`, `gitleaks`, `zizmor`,
   `kubeconform` and `trivy` (and `conftest` when Phase 2 adds policy as code). **`mise.lock` is committed** with
   URLs and, where the publisher provides them, checksums, for `macos-arm64`, `linux-arm64` and `linux-x64`.
2. **`[env]` holds the values several files share**: the Kubernetes minor and the k3s image tag. `compose.yaml`,
   `scripts/check` and the EKS module read them from there (the module through `TF_VAR_kubernetes_version`).
3. **`[tasks]` holds `up`, `down`, `reset` and `check`**, behaving as described in `docs/mac-migration.md` section 2, and
   adapted to the decisions of 2026-10-03: `up` is lean (ADR-0022 amendment), the runtime is the `yaaf` Colima VM, and
   `reset` deletes that VM.
4. **`scripts/check` runs the installed binaries.** It no longer needs Docker, so it is faster and the Windows path code
   (`cygpath`, `MSYS_NO_PATHCONV`) is deleted. `--ci` still treats a missing tool as a failure.
5. **CI installs from the lockfile** with `jdx/mise-action` pinned to a commit SHA and `mise install --locked`, replacing
   the per-workflow version settings (`tofu_version`, `TRIVY_VERSION`) and `opentofu/setup-opentofu`.
6. **The Trivy scan and the SBOM run the locked `trivy` binary**, not `aquasecurity/trivy-action`. One fewer
   third-party action in the trust chain after CVE-2026-33634 (76 of 77 `trivy-action` tags were repointed to a
   credential stealer on 2026-03-19; this repository was not exposed, being pinned by SHA to a later release). The same
   binary runs in the build, the weekly rescan and locally. SARIF still goes to the Security tab through
   `github/codeql-action/upload-sarif`.
7. **Container images stay digest-pinned in `compose.yaml`** (Floci, floci-dash): they are run, not installed tools.

## Rationale

A version written once cannot disagree with itself. The lockfile makes the toolchain reproducible and gives each
download a checksum, which the Docker-image digests did for the checkers but not for `tofu`, `kubectl` or Trivy. Using
the same binaries locally and in CI is the point of ADR-0009 (one definition of "the checks") carried one step further.

## Consequences / trade-offs accepted

- `awscli` is the one tool without a checksum in the lockfile. It is used by `up`, not by `check` or CI, so it does not
  weaken the gate; it is noted so the lockfile is not read as stronger than it is.
- `jdx/mise-action` joins the trust chain (SHA-pinned, covered by zizmor) and mise's `aqua` registry is trusted to
  name the right release assets; the lockfile checksums catch a changed download, not a wrong source.
- Nothing bumps `mise.toml` automatically. Bumps are a deliberate `chore/` PR (`mise upgrade --bump`, then `mise lock`),
  the same manual policy as Helm chart versions and compose digests. Written down here as a known gap.
- Acceptance checks before this is called done: `check` passes in CI from the lockfile; a planted fault is caught by each
  checker (the owner's rule for new checks); Trivy produces the same SARIF and gate result as `trivy-action` did, with
  `.trivyignore.yaml` honoured.
- The Kubernetes minor still has to be raised by hand when EKS supports a newer one, now in one place.
