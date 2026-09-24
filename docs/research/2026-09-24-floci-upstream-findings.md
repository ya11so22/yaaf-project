# Floci and floci-dash: findings worth reporting upstream

**Date:** 2026-09-24. **Versions:** Floci 2.1.0 (also read on `main`), floci-dash 0.4.0. **Status:** drafts. Nothing has
been filed; each item says where it should go. Searches of the upstream issue trackers on 2026-09-24 found no existing
report for any of them (keyword search only, so a differently worded issue could exist).

Serves the standing goal of one piece of external validation ([milestones](../milestones.md)).

## Floci (github.com/floci-io/floci): file as public issues

### F1. CloudFront: tags passed to `CreateDistributionWithTags` are stored under the wrong key and never read back

**Symptom.** A distribution created with tags reports none. With the AWS provider's `default_tags`, every plan shows the
distribution as changed.

**Reproduction.**

```bash
aws --endpoint-url http://localhost:4566 cloudfront create-distribution-with-tags --distribution-config-with-tags '{"DistributionConfig":{...},"Tags":{"Items":[{"Key":"Project","Value":"x"}]}}'
aws --endpoint-url http://localhost:4566 cloudfront list-tags-for-resource --resource arn:aws:cloudfront::000000000000:distribution/<Id>
# -> {"Tags":{"Items":[]}}
```

**Cause (read in the source).** `CloudFrontService.createDistribution` (2.1.0 line 147; `main` line 192) saves the tags
with `tagStore.put("distribution/" + id, tags)`, but `listTagsForResource(String arn)` reads `tagStore.get(arn)` with the
full ARN (`arn:aws:cloudfront::<account>:distribution/<id>`), and `tagResource` also writes under the ARN. The two keys
never meet.

**Suggested fix.** Store under `dist.getArn()`. Add a test that creates with tags and lists them.

### F2. IAM: `ListInstanceProfileTags` is not implemented

**Symptom.** `aws iam list-instance-profile-tags` returns `UnsupportedOperation`. `get-instance-profile` shows no `Tags`.
The AWS provider's `aws_iam_instance_profile` then reports a tag change on every plan when the provider uses
`default_tags` or the resource has tags, and cannot converge.

**Suggested fix.** Implement `Tag/Untag/ListInstanceProfileTags` and return tags from `GetInstanceProfile`.

### F3. EC2: the SSH port and security-group app ports are published on all interfaces, with no setting to change it

**Symptom.** After launching an instance with a key pair, `netstat` shows `0.0.0.0:2201` and `[::]:2201` listening.
Ports opened by security groups (socat sidecars, 30000 to 30999) are the same. The docs say they are published "so you
can reach the app from `localhost`", and that the rule's source CIDR is not enforced, so a rule for `127.0.0.1/32`
publishes to the whole network.

**Impact.** On a developer machine on a shared network, an emulated instance's SSH and app ports are reachable by anyone
on that network. `EmulatorConfig` has port-range settings (`FLOCI_SERVICES_EC2_SSH_PORT_RANGE_*`,
`..._APP_PORT_RANGE_*`) but no bind address.

**Suggested fix.** A setting for the host bind address, defaulting to `127.0.0.1`.

### F4. EC2: `MetadataOptions.HttpTokens=required` (IMDSv2 only) is not enforced

**Reproduction.** Launch an instance with `HttpTokens=required`, then inside it:
`curl -s -o /dev/null -w "%{http_code}" http://169.254.169.254/latest/meta-data/instance-id` returns `200` without a
token. Real AWS returns `401`.

### F5 (feature request). SSM Session Manager `StartSession`

`aws ssm start-session` returns `UnsupportedOperation`. Run Command works. Low priority; noted so the gap is documented.

## floci-dash (github.com/ofsazib/floci-dash): report privately

Its `SECURITY.md` asks for private reports through GitHub Security Advisories (`/security/advisories/new`), not public issues.

### D1. The EC2 terminal WebSocket does not check the page's `Origin`

**Reproduction (tested).** With the socket mounted, open the terminal WebSocket for a running instance while sending
`Origin: http://evil.example`:

```
GET /api/aws/ec2/instances/<instance-id>/terminal HTTP/1.1
Upgrade: websocket ... Origin: http://evil.example
-> HTTP/1.1 101 Switching Protocols, then a root shell in the instance
```

The HTTP API's CORS preflight returns no `Access-Control-Allow-Origin` for that origin, so browsers block cross-site HTTP
calls, but browsers do not apply CORS to WebSockets. `setupTerminalWebSocket` creates `new WebSocketServer({ server })`
without a `verifyClient` or an origin allow-list.

**Impact.** Any web page open in the same browser could open a shell in an EC2 instance's container if it knew the
instance ID (a 17-character random ID, so guessing is impractical; leaking it is not). Cross-site WebSocket hijacking.

**Suggested fix.** Reject upgrades whose `Origin` is not the dashboard's own origin.

### D2 (hardening). The instance ID is inserted unvalidated into a Docker API path

`getContainerName` returns `` `floci-ec2-${instanceId}` `` from the URL segment after `decodeURIComponent`, and
`dockerExecTty` puts it into `` `/containers/${containerName}/exec` ``. An encoded `/` or `..` in the ID changes the path.
**Not tested**, because exercising it means exec'ing into other containers; Docker's router may normalise or reject the
path. Suggest validating `^i-[0-9a-f]+$` before use. Since the dashboard holds the Docker socket, this is worth a check by
the maintainer.

## What was not found

- Telemetry or outbound calls in floci-dash: none found. Checked the source at v0.4.0: no external hosts in the backend or
  frontend code, no analytics packages (the one keyword match is the AWS Kinesis Analytics SDK), and its `fetch` calls go to
  `FLOCI_URL`. The terminal uses the Docker socket.
- The `test`-key bypass and the unenforced trust conditions on third-party issuers are documented Floci behaviour, not bugs
  (see [the IAM guide](../guides/iam-policies-and-trust.md)).
