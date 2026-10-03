# Mac migration: guidelines for rebuilding the operator tooling

The project moved from a Windows PC to a Mac on 2026-10-03. The Windows-only operator scripts (`scripts/dev-up.ps1`,
`scripts/dev-down.ps1`) were **deleted, not ported**. This file records what they did, which behaviours mattered and
which emulator quirks they worked around, so the Mac session can rebuild the smallest thing that works and improve it
there. The originals stay readable at the git tag `archive/windows-era`
(`git show archive/windows-era:scripts/dev-up.ps1`).

Principle (the owner's): **minimal scripts, tools do the work.** Prefer a task runner calling `docker compose`, `tofu`,
`aws` and `kubectl` directly over a long script that re-implements them.

## 1. Set up the Mac

| Need | Recommendation | Why |
|---|---|---|
| Container runtime | Docker Desktop or OrbStack (either; test one) | Floci needs a Docker socket at `/var/run/docker.sock` (it is mounted in `compose.yaml`). Docker Desktop: enable "Allow the default Docker socket" in Settings > Advanced. OrbStack provides it by default. Colima needs `--vz-rosetta` and a socket symlink. Give the VM 8 GB RAM: the cluster plus a Java build ran out at 6.6 GB on Windows. |
| Tool versions | [mise](https://mise.jdx.dev) with a `mise.toml` at the repo root | One file pins `opentofu` 1.12.x, `kubectl` 1.36.x, `awscli` 2, `gh`; mise tasks give the task interface below. Homebrew is fine for mise itself. |
| Assistant skills | Three Claude Code plugins at user scope, not in the repo (commands below) | Matt Pocock's skills used to be vendored under `.claude/skills` (removed). Now installed as plugins, so they update with `claude plugin update` and stay out of the repo: `mattpocock-skills` (27 skills: grilling, handoff, TDD, specs, reviews), `andrej-karpathy-skills` (one coding-guidelines skill) and `ponytail` (a "simplest thing that works" mode, with hooks that only write local state files; audited 2026-10-03). |
| Git hook | `git config core.hooksPath .githooks` | Runs `scripts/check` before each commit. |

Install the assistant plugins once (they land in `~/.claude/settings.json`):

```bash
claude plugin marketplace add mattpocock/skills
claude plugin marketplace add multica-ai/andrej-karpathy-skills
claude plugin marketplace add dietrichgebert/ponytail
claude plugin install mattpocock-skills@mattpocock --scope user
claude plugin install andrej-karpathy-skills@karpathy-skills --scope user
claude plugin install ponytail@ponytail --scope user
```

Watch out: ponytail is always on, at level `full`, and favours terse, minimal answers. That can clash with "the project is
also a course" (`CLAUDE.md`). Use `/ponytail lite` for a session, or set `PONYTAIL_DEFAULT_MODE=lite` to make it the
default.

## 2. The task interface to build (`mise.toml`)

Four tasks, each a handful of lines. Build them in this order and test each before the next.

### `up`: bring the local AWS up, idempotently

What the Windows `dev-up` did, in order. Keep the order; it matters.

1. **Start the runtime if needed**, wait for `docker info`.
2. `docker compose -f infra/environments/dev/compose.yaml up -d --wait --remove-orphans` (waits on Floci's own health
   check).
3. **SSH key for the EC2 workstation**: create `~/.ssh/floci-dev` (ed25519, no passphrase) once if missing, and pass only
   the public half as `TF_VAR_ssh_public_key`. Never let the private key reach OpenTofu.
4. `tofu -chdir=infra/environments/dev/bootstrap init && apply -auto-approve` (the state bucket; local state).
5. `tofu -chdir=infra/environments/dev/foundation init && apply -auto-approve` (S3 backend on Floci).
6. **Write the `floci` AWS CLI profile** from the foundation outputs `kubectl_access_key_id` and
   `kubectl_secret_access_key` (`-raw` / `-json`), with `region us-east-1` and `endpoint_url http://localhost:4566`.
   Floci's EKS auth rejects the dummy `test` keys; it needs this real IAM key.
7. `aws eks update-kubeconfig --name yaaf-dev --profile floci`, and take the context name from
   `aws eks describe-cluster --name yaaf-dev --query cluster.arn` (do not hard-code it). Run this on every `up`: the
   cluster's host port can change when its container is recreated.
8. **Wait for the cluster**: `kubectl get --raw=/readyz` and `kubectl wait --for=condition=Ready node --all`. Up to ~3 min.
9. **Repair if it does not become ready** (see quirk Q1): `docker rm -f floci-eks-yaaf-dev`,
   `docker volume rm floci-eks-yaaf-dev`, restart Floci, then repeat steps 5 to 8 once. Safe because the cluster's
   state is disposable: Argo CD restores every workload from git.
10. `tofu -chdir=infra/environments/dev/cluster apply -var target_revision=main -var kubeconfig_context=<arn>`
    (Argo CD and its Applications).
11. **Report**: wait until `kubectl -n argocd get applications` are all `Synced/Healthy`, then check each URL and print it.
    Check content, not status codes: Floci answers 200 on port 4566 for almost anything (quirk Q4). The portal URL is
    `http://$(tofu output -raw portal_domain_name):4566/`.

Options worth keeping: a revision (Argo CD tracks a branch, to try a change before merging; run plain `up` again after the
branch is merged and deleted, or Argo CD tracks a branch that no longer exists) and plan-only.

### `down`: stop, keep everything

`docker compose ... stop`, then `docker stop` any container labelled `floci=true` (the cluster and registry Floci started
itself). Stop gracefully: an abrupt stop is what leaves the cluster broken (Q1). Optionally back up
`infra/environments/dev/bootstrap/terraform.tfstate*` and the `yaaf-dev-tfstate` bucket first.

### `reset`: delete everything, for a clean start (ask first)

`docker compose ... down --volumes --remove-orphans`; `docker rm -f -v` every container labelled `floci=true`; remove volumes
labelled `floci=true` **and** volumes named `floci-eks-*` (the cluster's volume is not labelled, Q2); delete
`infra/environments/dev/bootstrap/terraform.tfstate*`. Never use the runtime's "purge data" button instead: it deletes
Floci's data but leaves the bootstrap state, so the next `up` thinks the state bucket exists.

### `check`: run `scripts/check`

Already portable bash. Needs Docker (for actionlint, zizmor, gitleaks, kubeconform) and `tofu` and `kubectl` on `PATH`.
Its `cygpath` branch is Windows-only and can be deleted on the Mac.

## 3. Emulator quirks the scripts worked around

| | Quirk (Floci 2.1.0) | Handling |
|---|---|---|
| Q1 | After an abrupt stop the k3s container comes back on a stale IP and exits, while Floci still reports the cluster `ACTIVE`; OpenTofu sees no drift. Floci also only restores the cluster when the EKS API is first called. | `up` checks the cluster itself and repairs it (step 9). |
| Q2 | The cluster's datastore volume `floci-eks-<name>` carries no `floci=true` label. | `reset` matches it by name. |
| Q3 | CloudFront drops tags given at creation, so the first re-apply "changes" the distribution; `ListInstanceProfileTags` is unsupported. | First is a known one-apply convergence (CI applies twice); second has `ignore_changes` in `modules/ec2-instance`. A fix for the first is drafted for upstream (`HANDOFF.md`). |
| Q4 | Port 4566 answers HTTP 200 for unknown hosts (an S3 list). | URL checks look for page content. |
| Q5 | CloudFront viewer requests route only by the generated domain. | `FLOCI_SERVICES_CLOUDFRONT_DOMAIN_SUFFIX=cloudfront.localhost` in `compose.yaml`. |
| Q6 | EC2 SSH (2200-2299) and security-group ports (30000-30999) are published on all interfaces, and the source CIDR is not enforced. | On Windows this needed a firewall rule. On macOS, check with `lsof -nP -iTCP -sTCP:LISTEN | grep -E ':22[0-9]{2}'`; block with the application firewall or `pf` if on a shared network. |
| Q7 | IAM is not enforced by default; IMDSv2-required is not enforced. | Documented; `scripts/drills/iam-trust.sh` shows enforcement mode. |

## 4. Windows-specific things that should simply disappear

- `curl.exe` and Host-header workarounds: macOS resolves `*.localhost` in `curl` too.
- `FLOCI_SERVICES_ECR_URI_STYLE: path` in `compose.yaml` was added because Docker Desktop on Windows could not resolve
  `*.localhost` registry names. Try removing it on the Mac; keep it if image pushes to Floci's ECR fail.
- PowerShell 5.1 compatibility rules, the login-time registry task, `%LOCALAPPDATA%` logs, `cygpath` in scripts.
- `act` (`.actrc`, removed): not needed. `scripts/check` covers the fast checks and CI runs the rest for free.

## 5. Apple Silicon: the one real porting risk

Floci, floci-dash, k3s and redis publish arm64 images. **The 12 app images are amd64-only.** The k3s node on a Mac is
arm64, so pods either run under the runtime's Rosetta/QEMU emulation (slow, sometimes broken for JVM and .NET) or fail
with `exec format error`. First thing to try on the Mac: `up`, then `kubectl -n boutique get pods`. The proper fix is in the
pipeline: build each service natively on `ubuntu-24.04` and the free `ubuntu-24.04-arm` runner and merge into one
multi-arch index (`docker buildx imagetools create`), attesting the index digest. That is a change to
`.github/workflows/reusable-container-image.yml`; write an ADR first.
