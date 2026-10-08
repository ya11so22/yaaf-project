# Guide: real AWS from a borrowed sandbox

**Related:** `PLAN.md` D43, D46; `.mise/tasks/sandbox`; the AWS rules block at the end of `CLAUDE.md`
**Evidence:** designed. The sign-in flow was tried from a cloud session up to the sign-in URL (2026-10-08); nothing
has run against a sandbox yet.

## The idea

Everything in this project runs on Floci, an emulator, because the owner's AWS account has no hard spending cap and
an agent with admin rights could create something billable by mistake. Some claims still deserve real AWS: does the
OpenTofu really apply, does EKS behave as the design says? The answer here is to **borrow** an account: training
providers (AWS Builder Center, KodeKloud, Pluralsight) hand out real AWS accounts for a few hours, then wipe them.
The bill is theirs, and the owner's account is never involved.

## How it works here

1. Open a sandbox (the free AWS Builder Center sandbox first: 8 hours, once a week, from selected workshops).
2. In a cloud session, ask the agent to run `mise run sandbox`. It runs `aws login --remote`, which prints a sign-in
   URL: open it on any device, sign in **to the sandbox**, and paste the code back. Credentials last 12 hours and can be
   renewed for 90 days without signing in again.
3. The task prints the signed-in account ID and stops. Only if that ID is the sandbox's does the next run go further:
   `mise run sandbox --account <id>`. It then sets up the **AWS Agent Toolkit**: AWS's skills for agents and the
   **AWS MCP server**, which gives the agent AWS tools with audit logging.
4. Point the MCP server at the profile: in the config file the toolkit wrote, add
   `"env": {"AWS_MCP_PROXY_PROFILES": "yaaf-sandbox"}` to the `aws-mcp` entry (otherwise it looks for a `default`
   profile and fails with `-32602`). Then restart the session's tools.
5. Run the evidence task, record it as *verified on real AWS (sandbox, date)* with logs, and tear everything down before
   the sandbox expires.

Two sets of AWS files never mix. `mise.toml` points the AWS CLI at `.aws/` in the repository, which holds only Floci's
emulator keys. The sandbox task unsets that and uses `~/.aws`, so a Floci command can never reach real AWS and a real
command never sees Floci's keys.

## Why this way

- **The owner's own account**, even read-only: rejected (D20). There is no hard spending cap for an existing account, and
  the 2026 spend limits exist only for new sign-ups.
- **Stored access keys** for the sandbox: never. `aws login` uses the console session, so nothing long-lived exists to
  leak.
- **A paid sandbox subscription**: an open question in the plan, only if the free one falls short.

## Watch out for

- **The account guard is a human check.** The task cannot tell a sandbox from your own account; it makes a person read
  the ID and type it. Read it.
- **`aws login` grants whatever the console sign-in has.** In a sandbox that is the vendor's role, often with service
  limits (regions, instance sizes, EKS caps). Expect refusals, and record them: they are findings.
- **The toolkit's wizard is interactive.** If it stops with exit code 253 ("requires interactive terminal"), it needs a
  real terminal; the troubleshooting page of the toolkit has the steps.
- **The sandbox expires mid-run.** Tear down first and keep the logs; an apply cut short leaves nothing behind in an
  account that is wiped anyway, but the evidence is lost.

## Check yourself

<details><summary>Why not just use your own account with a budget alert?</summary>

A budget alert reacts after billing data arrives, at least once a day, so a mistake is already paid for when it fires.
A borrowed sandbox cannot bill the owner at all.

</details>

<details><summary>How do you keep emulator credentials and real ones apart?</summary>

Different files by construction: the repository's `.aws/` for Floci (set by `mise.toml`), `~/.aws` for the sandbox
(the task unsets the override). A command uses one or the other, never both.

</details>
