# Guide: Kubernetes probes, and a service that restarted forever

**Related:** [`deploy/dev/kustomization.yaml`](../../deploy/dev/kustomization.yaml),
[journal](../journal/2026-09-24-reset-and-local-aws-rebuild.md)
**Evidence:** verified on Floci (the fix was applied live and the pod started with no restarts, 2026-09-24)

## The idea

Kubernetes asks each container three different questions, through three probes:

| Probe | Question | If it fails |
|---|---|---|
| **startup** | Has it finished starting? | Keep waiting, up to its limit; the other probes do not run yet |
| **liveness** | Is it still alive? | Restart the container |
| **readiness** | Can it take traffic now? | Remove it from the Service's endpoints; no restart |

Without a startup probe, liveness starts checking straight away. A container that starts slowly is then killed for
being "dead" while it is still starting up.

## How it works here

On the rebuilt cluster, `emailservice` (Python) went into `CrashLoopBackOff`. The investigation, in order:

1. **Logs** said "listening on port: 8080", so the code was not crashing.
2. **Events** said the liveness probe "failed to connect ... within 1s", then "Killing".
3. **Hypotheses ruled out with evidence:** the image matched the source (so not the broken change from the failure
   drill); the node was at 2% CPU (so not contention); IPv6 was enabled (so not the `[::]` bind).
4. **Timing** found it: the container started at :11, logged "listening" at :25 (14 seconds, under a 200m CPU limit),
   and was killed at :30. Liveness checks every 5 seconds and kills after 3 failures, about 15 seconds, so it was
   killed just as it became ready, every time.

The fix is in the platform's overlay, not the app: a startup probe with up to 30 checks, 2 seconds apart (60 seconds),
added by a kustomize patch. It was proved before merging by pausing Argo CD's auto-sync for that one app, patching the
live Deployment, watching it start with zero restarts, then restoring auto-sync.

## Why this way

- **A startup probe, not a longer liveness delay.** `initialDelaySeconds` on liveness would also work, but it delays
  failure detection for the container's whole life. A startup probe only covers the start.
- **Not a bigger CPU limit.** That hides the symptom and costs capacity on every replica.
- **In `deploy/`, not `app/`.** The app's manifests stay upstream's; the platform owns how it runs here.

## Watch out for

- **"Listening" in the logs is not proof that the probe can connect**; read the events (`kubectl describe pod`).
- **Exit code 137** means the container was killed (SIGKILL), here by the kubelet after a liveness failure, not by the
  app. It is also what an out-of-memory kill looks like, so check the events to tell them apart.
- **Fixing it live under GitOps does not last.** Argo CD's self-heal reverts a hand patch within seconds. Pause
  auto-sync for the test, then restore it; the real fix goes through git.
- **Throttled starts vary.** A service can start fine on one machine and fail on a slower or busier one. Probes should
  be set from measured start times, with room to spare.

## Check yourself

<details><summary>A pod restarts every 30 seconds, and its logs look healthy. Where do you look?</summary>

`kubectl describe pod`: the events show probe failures and "Killing". Then compare how long the container takes to
become ready with the probe's `periodSeconds` × `failureThreshold`.

</details>

<details><summary>What is the difference between liveness and readiness failing?</summary>

Liveness failing restarts the container. Readiness failing only takes it out of the Service, so no traffic reaches it,
and it stays running until it recovers.

</details>
