# Guide: the first apply of the account root, from CloudShell

**Related:** [PLAN.md](../../PLAN.md) D55 to D57 (the Free-plan route, CloudShell applies, the Knowledge MCP), stage 2a;
`infra/account/` (the root); `infra/account/tests/` (the offline tests).
**Evidence:** designed, and tested offline (`tofu test`, 4 runs, with planted faults caught on 2026-10-13). **Not yet
applied to AWS.** Each step below is marked *to verify* until it has run for real, and the result is recorded here with a date.

## What the root creates

- A state bucket, `yaaf-<account-id>-tfstate`: versioned, encrypted with AWS-managed keys, public access blocked, and
  protected from deletion (`prevent_destroy`).
- A permissions boundary, `yaaf-tofu-boundary`: the ceiling on what the deployer can do. It denies leaving the account
  or changing billing, denies changing the boundary itself, and denies creating users or roles that do not carry it.
- A deployer role, `yaaf-tofu-deployer`, with AdministratorAccess capped by that boundary. Only your own identity may
  assume it.

Nothing else. No VPC, no cluster, no NAT gateway, no key with a monthly fee.

## Before you start (you do these; the agent does not)

1. **Confirm the Region** in AWS Settings, Project, Additional Info. Expect `us-east-1` (D54). If it says `us-east-2`, stop:
   the root's default changes, and the plan is updated first.
2. **Note the account ID**, from the same page. It is not secret, but never guess it.
3. **Find the identity you sign in with**, and its ARN (for example from the IAM console, or
   `aws sts get-caller-identity` in CloudShell). *To verify:* in the new experience, the owner may sign in through a
   social provider rather than an IAM user. If the ARN is an assumed-role session, use the role's ARN, not the session's.
4. **Check the credits and the expiry:** the account opened on 2026-10-12, so the six-month period ends 2027-04-12. Note
   the credit balance in Billing.

## In CloudShell

1. Open CloudShell in `us-east-1` (or the project's Region). It is signed in as you; nothing is stored by hand.
2. Install the OpenTofu version pinned in `mise.lock` (1.13.1), checking its checksum against the lock file. *To verify:* the
   install path, since CloudShell has no OpenTofu preinstalled.
3. Clone the repository and go to the root:
   ```bash
   git clone https://github.com/ya11so22/yaaf-project && cd yaaf-project/infra/account
   ```
   CloudShell's home directory has 1 GB and is deleted after 120 days without a session, so keep nothing there that is not
   also in git or in the state bucket.
4. Run the offline tests first, which need no credentials: `tofu init && tofu test`. They must pass before anything else.
5. Plan, and read it: `tofu plan -var account_id=<id> -var deployer_trusted_principal_arn=<your ARN> -out=bootstrap.tfplan`.
   The plan must create exactly the resources listed above and nothing else.
6. Apply the saved plan only: `tofu apply bootstrap.tfplan`. Saving the plan first means what you reviewed is what runs.

## After the apply

- **Migrate the bootstrap's own state into the bucket it created**, so it is not left in CloudShell's home. Add an `s3`
  backend block to `versions.tf` pointing at `yaaf-<id>-tfstate`, then `tofu init -migrate-state`. *To verify* on the real
  account, since it is the first use of the bucket.
- **Check what AWS actually enforces**, with a deliberate attempt that the boundary must refuse (for example creating a user
  without the boundary, using the deployer role). Record the result and the date here. The offline tests only prove the
  policy's text.
- Record the apply in PLAN.md's log, with the account's credit balance.

## Watch out

- The state bucket cannot be deleted by a normal apply (`prevent_destroy`). To remove it on purpose, that flag is changed in a
  reviewed commit first.
- The boundary is a ceiling, not a grant. With AdministratorAccess on the deployer, a missing boundary statement would let
  the deployer do anything. That is why the boundary's tests exist.
- The KMS finding in `main.tf` is an accepted Trivy finding with an expiry. It is reviewed at stage 2a, not forgotten.
