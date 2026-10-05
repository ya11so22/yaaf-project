# 2026-10-05: A lean `up`, the extras root, and what quirk Q1 really was

**Phase:** cross-cutting (the Mac era, step 5)
**Related ADRs:** [0022](../../adr/0022-the-local-aws-environment.md) (amended), [0006](../../adr/0006-github-oidc-role-design.md) (amended)

## What happened

- Deleted the ECR module, and with it the `ecr-push` OIDC role (a role with nothing to push to is invalid policy). `tofu-plan` and `tofu-apply` stay.
- Moved the workstation to a new, optional `extras` root and floci-dash to a compose profile. `mise run up` is lean; `mise run up --extras` adds both.
  The workstation's SSH key is kept in the repository's `.ssh/` (gitignored), never `~/.ssh`.
- The `extras` root is applied and checked for idempotence in CI's smoke test, and validated with the other roots.
- Fixed `up` so it no longer rebuilds a healthy cluster (below), and made the workstation arm64 so SSH works.

## Verification

*Verified on Floci, on the Mac:*

- The lean `up` against the existing environment: the foundation apply **destroyed 33 resources** (12 ECR repositories and their policies, the `ecr-push`
  role, the old workstation and its key) and the plan was clean afterwards; shop, Argo CD, Headlamp and the portal all `OK`.
- `up --extras`: 8 resources added; floci-dash and the shop `OK`; a workstation reachable by **SSH with the project key** (`root` on `aarch64`,
  Ubuntu 24.04.5) and by **SSM Run Command** (`aarch64`). The browser console terminal was not exercised from here.
- **The Q1 fix was proven against the real failure.** A fake node with no kubelet, planted beside the real one, goes `NotReady` as a stale one does.
  The old check (`wait --for=condition=Ready node --all`) **failed**; the new check (API answers and one node Ready) **passed**; pruning then removed
  the ghost and even the old check passed.

## Findings

1. **Quirk Q1 was a ghost node, not a dead cluster.** The diagnostics added on 2026-10-04 caught it: a `running exit=0` k3s container, and two
   nodes: the new one `Ready`, a leftover from the previous container `NotReady` for 166 minutes. Floci registers the recreated container under a
   new name and the old Node object never goes away, so the check "every node Ready" could never succeed, and `up` rebuilt a working cluster.
   The diagnostics were worth their cost; the guess ("stale IP", from Windows) was wrong on the Mac.
2. **A provider endpoint must outlive its resources.** I removed the `ecr` endpoint from the provider and the next apply failed refreshing the
   ECR repositories still in state (it went to the real AWS endpoint). Restored it for one apply, then removed it again; the plan was clean.
3. **SSH to an amd64 image on an arm64 Mac cannot work.** `sshd` under QEMU user-mode emulation fails its seccomp sandbox
   (`prctl(PR_SET_SECCOMP): Invalid argument`) and drops every connection after key exchange; found by running a debug `sshd` in the instance.
   Floci offers `ami-ubuntu2404-arm64`, which runs natively.
4. **Floci's instance images are minimal.** `uptime` is missing, so an SSM command using it fails; that was the command, not SSM.
5. **Quirk Q6 holds on the Mac.** `lsof` shows the workstation's SSH port on `*:2200` while the project's services are on loopback. It now exists
   only with `--extras`.

## Learn

- Capture evidence at the point of failure before the repair destroys it: the diagnostics settled in one run what a day of guessing did not.
- When a check can fail for a reason that is not the thing you care about (a stale object), test it against that exact false failure.
- Emulation is a platform too: "the TCP port accepts, then closes" can mean the process cannot run its own sandbox.

## Next

Phase 1 close-out: the pre-merge deploy check, guardrails for agent pull requests (an ADR first), and the threat model. Then the scenario library.
