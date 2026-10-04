# Research: reliability at low cost, and guardrails for AI-written change (October 2026)

**Date:** 2026-10-04. **Feeds:** the Phase 1 close-out (CI guardrails), the scenario library ([ADR-0028](../../adr/0028-scenario-library.md)),
Phase 2 and the architecture track. An ADR for the guardrails is written before they are built. **Evidence labels:** *primary*
(the standards body or vendor documentation), *vendor research* (a vendor's own study, with a commercial interest),
*survey* (self-reported), *inference* (this project's reasoning, not a sourced finding).
**Method:** a multi-agent web search (110 agents) with three-vote adversarial checks on every claim, read against the
repository. Claims that failed verification are listed in section 4 so they are not reused.

## 1. Questions

1. What must a DevOps, platform or solutions architect handle today: drift, partial failures, traffic spikes, cost, and
   observability that stays useful? What can this project show on a single-node local emulator, and what only as a design?
2. The owner's own concern: fast AI-written code reaching production through CI. Is it a platform concern or only a developer
   one, which guardrails are worth having, and should the project present it?

## 2. Findings

### 2.1 Reliability, cost and observability

- **SLO alerting: multiwindow, multi-burn-rate** (primary, [Google SRE Workbook](https://sre.google/workbook/alerting-on-slos/), table
  5-8). The chapter calls it "the most appropriate approach" in most cases. Starting values for a 99.9% SLO over 30 days:
  | Severity | Burn rate | Long window | Short window | Budget used |
  |---|---|---|---|---|
  | Page | 14.4 | 1 h | 5 min | 2% |
  | Page | 6 | 6 h | 30 min | 5% |
  | Ticket | 1 | 3 days | 6 h | 10% |
  Sloth and Pyrra generate the Prometheus rules. **Watch out:** demo traffic is too low for burn rates to mean anything, so a
  demonstration needs synthetic load (the vendored load generator or k6).
- **Drift needs two mechanisms** (primary). Inside the cluster, Argo CD automated sync with `prune` and `selfHeal`; without
  `prune`, resources removed from git stay running, shown only as OutOfSync
  ([Argo CD](https://argo-cd.readthedocs.io/en/latest/user-guide/auto_sync/)). Every Application here already sets both. For
  the cloud layer, `tofu plan -refresh-only -detailed-exitcode`: exit 0 no drift, 1 error, 2 drift
  ([OpenTofu](https://opentofu.org/docs/cli/commands/plan/)). Both run on Floci at no cost.
- **Partial failures: retry at one layer only** (primary, [AWS Well-Architected REL05-BP03](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/rel_mitigate_interaction_failure_limit_retries.md)).
  Retry only retryable, idempotent calls, with capped exponential backoff and jitter. Not doing so is rated High risk. Three
  attempts at each of *n* layers is 3^n calls on the bottom service, and uncapped retries turn overload into metastable failure.
  Online Boutique's frontend fans out to several services over gRPC, which makes it a good place to show it.
- **Cost** (primary guidance, uncited figure). AWS's EKS cost guidance says typical clusters run at 20–30% utilisation and
  names observability (high-cardinality metrics, verbose logs) as a cost driver
  ([AWS](https://docs.aws.amazon.com/prescriptive-guidance/latest/eks-cost-optimization/introduction.html)). Cite it as "AWS
  guidance says": the figure is uncited and the page's own arithmetic is inconsistent. "Shift left" (cost context earlier) is
  among the FinOps Foundation's 2026 priorities (survey, stated priorities, not proof).
- **Observability** (primary for sampling; survey for pain points). OpenTelemetry: head sampling is cheap but can drop error
  traces; tail sampling keeps errors and slow traces but is stateful and hard to operate; low-volume systems may not need
  sampling at all ([OpenTelemetry](https://opentelemetry.io/docs/concepts/sampling/)). In Grafana's 2026 survey (n=1,363, a
  multi-select convenience sample), complexity (38%), signal-to-noise (34%) and cost (31%) were the top concerns
  ([Grafana Labs](https://grafana.com/press/2026/03/18/grafana-labs-4th-annual-observability-survey-reveals-a-field-at-a-crossroads-ai-economics-complexity-and-the-enduring-power-of-open-source/)).

### 2.2 AI-written change

- **It is a delivery-system concern, not only a developer one** (survey, correlational). DORA 2025 (about 5,000 respondents):
  "AI doesn't fix a team; it amplifies what's already there", and without strong control systems (automated testing, version
  control, fast feedback) more change volume leads to instability
  ([DORA](https://cloud.google.com/devops/state-of-devops),
  [announcement](https://cloud.google.com/blog/products/ai-machine-learning/announcing-the-2025-dora-report)). Control systems
  are platform work. This is the anchor citation.
- **Less refactoring, more copying** (vendor research, not peer reviewed). GitClear, 211M changed lines 2020–2024: moved lines
  (its refactoring proxy) fell from 24.1% to 9.5%, and in 2024 copy/pasted lines outnumbered moved lines for the first time
  ([GitClear](https://www.gitclear.com/ai_assistant_code_quality_2025_research)). The lines are not attributed to AI; the link
  is GitClear's inference. Cite the specific metric, not the page's "4x" tagline.
- **Insecure choices in a security benchmark** (vendor research). Veracode, 80 curated security-sensitive tasks, 100+ models:
  the insecure option was chosen in 45% of tasks, Java worst (over 70%); larger models were not significantly better. The
  July 2026 update puts the average security pass rate at about 56% (best model 68%)
  ([Veracode](https://www.veracode.com/press-release/ai-generated-code-poses-major-security-risks-in-nearly-half-of-all-development-tasks-veracode-research-reveals/)).
  **Not** "45% of AI code is vulnerable": the tasks were chosen to invite weaknesses and the prompts gave no security guidance,
  and Veracode sells the scanner that scored them.

### 2.3 This project

*Inference, read against the repository:*

- **The concern is concrete here.** The app team is AI agents opening pull requests against `app/src` (`CLAUDE.md`), and one
  GitHub identity plays both roles, so required human review cannot be enforced. Automated gates are the only enforceable
  controls.
- **It has already happened twice.** The Phase 1 failure exercise: a broken `emailservice` passed every check because "no
  check starts the service before merge" ([postmortem](../postmortems/2026-09-21-phase1-bad-emailservice.md)). On 2026-10-03,
  Python images labelled arm64 held `x86_64` Python ([ADR-0027](../../adr/0027-arm64-only-app-images.md)). Both are fragile
  changes that CI accepted.
- **The app is polyglot and vendored** (Go, C#, Java, Node, Python, Google's code), so per-language architecture rules,
  coverage gates and mutation testing cost a lot and guard code that is not the project's own.

## 3. Conclusions

### 3.1 Build: CI guardrails for agent pull requests

Language-agnostic, cheap, each proven against a planted fault before it is trusted (the owner's rule). In order:

1. **The pre-merge deploy and smoke check** (already planned): deploy the changed services to a throwaway environment and
   require them to become Ready and answer. It closes the gap the emailservice exercise found.
2. **An agent scope check**: a pull request from the app-team agent that changes anything outside `app/src` fails. It turns
   the `CODEOWNERS` convention into enforcement.
3. **A dependency gate**: new or changed dependencies must exist in their registry and be locked, and are listed in the PR.
   *Designed:* the size of the hallucinated-package risk was not verified (section 4), so this is cheap insurance, not a
   measured threat.
4. **A pull-request size limit** for agent PRs: small batches, made mechanical.
5. **SAST** (Semgrep or CodeQL) on `app/src` changes: report first, then a gate on new high findings, the same ratchet as the
   Trivy gate (ADR-0024).

Not built: AI-authorship labels as a control (trivially bypassed; the gates apply to every change), per-language
architecture rules, mutation testing, coverage gates.

### 3.2 Build: on Floci

- A **drift** task and scenario: `tofu plan -refresh-only -detailed-exitcode`, with a resource changed by hand outside the code.
- **SLOs with burn-rate alerts** for the checkout path (Sloth or Pyrra), proved against a planted fault under synthetic load
  (Phase 2).
- A **cascading-failure** scenario: one retry layer with timeouts, and the failure injected before and after.
- **Pod-level scaling**: a HorizontalPodAutoscaler on `frontend` under a load test. *Not verified by this research*; included
  because it is the only spike behaviour a single node can show.
- **Canary rollouts with automated analysis** (Argo Rollouts and Prometheus), the last line of defence for either theme.
  Phase 2, once metrics exist.

### 3.3 Designs only (architecture track)

Node autoscaling (Karpenter), Spot and Graviton fleets, multi-AZ and multi-Region recovery, OpenTelemetry tail sampling, and
a cost model per reliability tier with Pricing Calculator estimates. A single 8 GB node cannot show them, and claiming it
would break the evidence rule.

### 3.4 How to present it

One storyline: *a platform that stays reliable, affordable and observable as change volume rises, including change written
by AI.* The two themes meet there: more change means more drift and more incidents, and the same gates and SLOs control both.
Frame the AI part as engineering risk control for an agent-driven team, anchored on DORA, not as an opinion about AI. Leave
out "AI slop" wording. *No verified evidence was found on what hiring managers look for here*; this framing is inference.

## 4. Claims not to reuse

Refuted in verification, or not verified, as of 2026-10-04:

- **Refuted:** that DORA's AI Capabilities Model has seven named practices as commonly listed (do not enumerate it from
  memory); that Argo CD self-heal retries after a 5-second default; that 30% of Grafana's respondents named alert fatigue the
  biggest obstacle; that copy/pasted lines rose from 8.3% to 12.3%.
- **Not verified:** METR's "developers were 19% slower with AI" (2025); the "19.7% of suggested packages do not exist"
  slopsquatting figure; "traces are 60–70% of observability cost"; DORA's specific instability figures. Read the primary papers
  before citing any of these.
