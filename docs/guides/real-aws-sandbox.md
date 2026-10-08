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
   URL: open it on any device, sign in **to the sandbox**, and paste the code back. Each first run signs out and in
   afresh, so last week's sandbox cannot linger.
3. The task prints the signed-in account ID and stops. **You** compare it with the account ID on the sandbox's own
   page and, only if they match, give it to the agent, which continues with `mise run sandbox --account <id>`. If
   `YAAF_OWNER_ACCOUNT_ID` is set in the cloud environment's settings, signing in to your own account is refused and
   signed out before that point. It then sets up the **AWS Agent Toolkit**: AWS's skills for agents and the
   **AWS MCP server**, which gives the agent AWS tools with audit logging.
4. Point the MCP server at the profile: in the config file the toolkit wrote, add
   `"env": {"AWS_MCP_PROXY_PROFILES": "yaaf-sandbox"}` to the `aws-mcp` entry (otherwise it looks for a `default`
   profile and fails with `-32602`). Then restart the session's tools.
5. Run the evidence task, record it as *verified on real AWS (sandbox, date)* with logs, tear everything down before
   the sandbox expires, then `aws logout --profile yaaf-sandbox`.

Two sets of AWS files never mix. `mise.toml` points the AWS CLI at `.aws/` in the repository, which holds only Floci's
emulator keys. The sandbox task unsets that and uses `~/.aws`, so a Floci command can never reach real AWS and a real
command never sees Floci's keys.

## Why this way

- **The owner's own account**, even read-only: rejected (D20). There is no hard spending cap for an existing account, and
  the 2026 spend limits exist only for new sign-ups.
- **Stored access keys** for the sandbox: never. `aws login` uses the console session: it caches 12-hour credentials and
  a refresh token that can renew them for up to 90 days. That token is a secret in `~/.aws`; it lives only in the
  session's throwaway container, and `aws logout` at the end removes it. The sandbox account is wiped anyway.
- **A paid sandbox subscription**: an open question in the plan, only if the free one falls short.

## Watch out for

- **The account guard is partly a human check.** The script can refuse your own account only if `YAAF_OWNER_ACCOUNT_ID`
  is set; beyond that it cannot tell where an ID came from. The agent is told never to continue from the task's own
  output, and you give the ID from the sandbox's page. Read it. The guards are tested against a fake `aws`
  (`scripts/sandbox.test.sh`, in `mise run check`), including a planted fault that removes the owner check.
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
