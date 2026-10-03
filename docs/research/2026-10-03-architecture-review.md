# Research: a fresh review of the architecture and tooling (October 2026)

**Date:** 2026-10-03. **Feeds:** the Mac setup (HANDOFF item 1) and ADRs still to be written. **Evidence labels:**
*primary* (the vendor), *secondary* (blogs, security firms), *tested* (run on this Mac or in this repository).
**Method:** a multi-agent web search with three-vote adversarial checks on every claim, plus a read of the repository and
direct checks of release pages on 2026-10-03.

## 1. Questions

1. With fresh eyes, what in the current design is weaker than it needs to be?
2. Are the tools current, and do newer versions change any decision?
3. What runtime and VM shape should the Mac use?

## 2. Findings

### 2.1 Keep: decisions that hold up

- **Floci over LocalStack** (primary). LocalStack ended its token-free Community edition on 2026-03-23; its one image now
  needs an account and auth token, and the free Hobby tier forbids commercial use
  ([LocalStack](https://blog.localstack.cloud/2026-upcoming-pricing-changes/),
  [InfoQ](https://www.infoq.com/news/2026/02/localstack-aws-community)). Floci needs neither
  ([README](https://github.com/floci-io/floci)). ADR-0022's choice stands.
- **The GitHub App bot that pins digests** (primary). Each alternative adds a moving part: Argo CD Image Updater v1 is an
  in-cluster controller with an `ImageUpdater` CRD
  ([docs](https://argocd-image-updater.readthedocs.io/en/latest/configuration/migration/)); Kargo is a promotion layer
  that pays off with several stages, and dev is the only one ([kargo.io](https://kargo.io/)); Renovate's `argocd`
  manager matches no files until configured ([docs](https://docs.renovatebot.com/modules/manager/argocd/)).
- **Attestations** (primary). `actions/attest@v4` for both provenance and SBOM, with `id-token`, `contents`,
  `attestations` and `packages` permissions, is what GitHub now documents
  ([docs](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations)).
  The pipeline already does exactly this.
- **SHA pins after the Trivy compromise** (primary). CVE-2026-33634 repointed 76 of 77 `trivy-action` tags on
  2026-03-19 ([advisory](https://advisories.gitlab.com/golang/github.com/aquasecurity/trivy/CVE-2026-33634/)). This
  repository pins `trivy-action` v0.36.0 (released 2026-04-22, after the incident) by SHA: not affected.
- **mise as the task runner** (designed). It is already the planned tool-version manager; `just` or Task would be a second
  tool for the same job.

### 2.2 Change: ranked by value for effort

1. **Give the project its own Colima VM** (tested). The Mac (M2, 8 cores, 16 GB) runs Colima's default profile at
   2 CPUs, 2 GiB, Rosetta off, shared with the owner's other containers. A dedicated profile `yaaf`
   (`vz`, Rosetta, 4 CPUs, 8 GiB) is a separate VM with its own containers and volumes and its own Docker context
   ([Colima](https://colima.run/docs/profiles/)). Consequences: `reset` becomes `colima delete yaaf` (no label hunting;
   quirk Q2 disappears); `down` can free the memory; the project cannot touch other containers. Tested: an amd64 container
   runs under Rosetta (`uname -m` gives `x86_64`) and a Docker-socket mount works. **Watch out:** `colima start` switches
   the *global* Docker context; the project should select `colima-yaaf` through `DOCKER_CONTEXT` in `mise.toml`, never by
   switching the global context. *Not yet tested:* whether Rosetta reaches pods inside Floci's nested k3s.
   OrbStack was considered: free for personal use only ([pricing](https://orbstack.dev/pricing)), and switching would
   migrate the owner's other containers for little gain.
2. **One source of tool versions** (designed). Versions are pinned in several places that only memory keeps in step:
   Kubernetes 1.36 in `compose.yaml`, `scripts/check` and `modules/eks-cluster`; OpenTofu `1.12.6` in `infra.yml` only;
   the checkers as Docker digests in `scripts/check`; Trivy v0.74.0 in the build but **unpinned in `rescan.yml`**, so the
   weekly rescan and the gate can disagree. Proposal: `mise.toml` pins `opentofu`, `kubectl`, `awscli`, `gh`,
   `actionlint`, `gitleaks`, `zizmor`, `kubeconform` and `trivy`; CI installs the same file with `jdx/mise-action`
   (SHA-pinned); `scripts/check` calls binaries instead of one `docker run` per tool, so the check gets faster and no
   longer needs Docker. Needs an ADR amending ADR-0009. To verify before adopting: the checksum and signature checks mise
   performs per backend.
3. **Argo CD Applications in git, not HCL** (primary pattern, designed here). The five Applications live as HCL in the
   `cluster` root, so changing Traefik or Headlamp needs `tofu apply`: delivery is GitOps for the app but not for the
   platform. Argo CD documents app-of-apps and self-management
   ([docs](https://argo-cd.readthedocs.io/en/release-3.2/operator-manual/declarative-setup/)). Proposal: the `cluster`
   root installs Argo CD and **one** root Application pointing at `deploy/apps/`; every other Application is a YAML file
   there. Letting Argo CD then manage itself is a second, optional step (OpenTofu 1.12's `lifecycle { destroy = false }`
   or a `removed` block hands it over without an uninstall); keep a manual reinstall path. Needs an ADR amending 0022/0023.
4. **A plan that shows the real diff** (designed). The PR plan runs against empty state, so it always reads "create
   everything". In the smoke job, apply `main`'s foundation to the fresh Floci first, then plan the PR's code: the comment
   becomes the change itself. Costs a few CI minutes.
5. **Bump OpenTofu and raise the floor** (primary, release page checked). OpenTofu **1.13.1** shipped 2026-10-01 (the
   research agents' claim of a 1.13.0 date was refuted, but the release page itself lists 1.13.0 and 1.13.1). 1.11 added
   ephemeral resources and write-only attributes; 1.12 added `destroy = false`
   ([1.11](https://opentofu.org/blog/opentofu-1-11-0), [1.12](https://github.com/opentofu/opentofu/blob/v1.12/CHANGELOG.md)).
   `required_version = ">= 1.10"` allows neither; raise it to what the code uses.
6. **Small version bumps** (release pages, 2026-10-03): argo-cd chart 10.9.2 → 10.9.6, argocd-apps 2.0.5 → 2.0.6,
   Trivy 0.74.0 → 0.75.0. Nothing bumps Helm chart versions in HCL or compose digests automatically; that is the
   deliberate manual policy, now written down here as a known gap.
7. **arm64 images, arm64 only** (HANDOFF item 3, revised; *tested* on this Mac). The Mac, the VM, Floci and k3s are
   already arm64; only CI's `platforms: linux/amd64` makes the app amd64. **Correction of an earlier claim in this
   review:** the Dockerfiles do *not* work unchanged on an arm64 builder. Every Dockerfile declares
   `ARG BUILDPLATFORM=linux/amd64` (and Go and .NET services also `ARG TARGETARCH=amd64`) as "defaults in case the builder
   provides none", and those defaults win over the real values. Tested with `buildx build --platform linux/arm64`:
   all four Python services built and were labelled arm64 but their Python reported `x86_64` (an amd64 base running under
   Rosetta, a silently wrong image); all four Go services crashed in the amd64 Go toolchain and `cartservice` failed with
   `dotnet restore -a amd64`. Passing `--build-arg BUILDPLATFORM=linux/arm64 --build-arg TARGETARCH=arm64` made every one of
   them build, with `aarch64` Python and `ELF ... ARM aarch64` binaries (full table in ADR-0027). **Decision:** CI builds on native `ubuntu-24.04-arm` runners and passes those two build
   args, which keeps the vendored `app/` untouched (editing it would need modification notices under Apache-2.0). Add a
   check that the built image really holds arm64 binaries, so a mislabelled image cannot ship: this trap makes a good
   scenario for the library. One digest to attest; no `imagetools` merge. It maps to Graviton for the architecture
   track.

### 2.3 Remove

- `cygpath` and `MSYS_NO_PATHCONV` in `scripts/check` (Windows only).
- `FLOCI_SERVICES_ECR_URI_STYLE: path` in `compose.yaml`, if an image push to Floci's ECR works without it on the Mac.
- `reset`'s label-and-name volume hunt, replaced by deleting the project's VM (item 1).

## 3. Open questions

- Does Floci 2.1.0's k3s survive an abrupt stop on the Mac (quirk Q1), and does Rosetta reach pods inside it?
- Which digest to attest for a multi-arch image.
- Whether replacing the bash hook with prek (a single binary that reads `.pre-commit-config.yaml`, [prek](https://prek.j178.dev/))
  earns its place: only if a declarative config replaces `scripts/check`, which ADR-0009 deliberately avoids.

## 4. Versions checked on 2026-10-03

| Tool | In repo | Latest |
|---|---|---|
| OpenTofu | 1.12.6 (CI) | 1.13.1 |
| Argo CD chart / app | 10.9.2 | 10.9.6 / v3.5.3 |
| argocd-apps chart | 2.0.5 | 2.0.6 |
| Trivy | 0.74.0, and unpinned in `rescan.yml` | 0.75.0 |
| k3s | v1.36.4 | v1.37.1 (stay on 1.36: the newest EKS version) |
| Floci / floci-dash | 2.1.0 / 0.4.0 | same |
| actionlint, gitleaks, zizmor, kubeconform | 1.7.12, 8.30.1, 1.30.1, 0.8.0 | same |
| Traefik chart, Headlamp | 41.6.0, 0.45.0 | Headlamp same |
| hashicorp/aws, hashicorp/helm | `~> 6.0`, `~> 3.x` | 6.67.0, 3.3.0 |
| mise | — | v2026.10.1 |
