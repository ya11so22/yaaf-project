# ADR-0010: Position for the US DevOps, platform and AI-infrastructure market; reorder the phases

**Status:** accepted (amends [ADR-0008](0008-phase-reslice-cd-and-team-model.md) on phases 2 to 4)
**Date:** 2026-09-20

## Context

The project's purpose is hiring signal for a DevOps engineer with 2-3 years of experience, currently
at a regulated bank on Jenkins, OpenShift and on-prem, who wants to move to a US role and is
planning to relocate. The owner asked whether the project is worth presenting and what to invest in,
and was open to redefining it.

Evidence gathered (quality matters, so it is stated):

- A multi-agent deep-research run: 99 agents, 17 sources fetched, 67 claims extracted, the top 25
  each put to three independent verification votes. **14 were confirmed and 11 refuted.** What
  survived: the project's stack (Kubernetes, Terraform, AWS, CI/CD, security) is the most-requested
  one; 2-3 years sits at the low edge of the typical 3-5 year band; portfolio guides name CD with
  rollback, monitoring and a postmortem as the expected patterns; OpenTofu is gaining but postings
  still say Terraform. What was refuted or split: that a live URL is required, that observability
  differentiates, that projects beat certifications, that README structure matters. The sources
  were almost all recruiter and career blogs. Nothing verified covered the Israeli market, Floci,
  GitOps, SLOs, policy-as-code, or MLOps.
- A lighter, **unverified** search pass on MLOps and AI infrastructure in the US: recruiter and
  vendor blogs report strong and growing demand, a mid-level pay premium, and describe the role as
  "platform SRE for ML systems" (serving, observability, reliability, rollback) more than model
  research. The blogs have hiring-industry incentives, so the numbers are directional only. One
  source put CKA in under 1% of MLOps postings.

Findings about the project itself: it evidences the skills the owner's job does not exercise (AWS,
EKS, OpenTofu, GitHub Actions, OIDC, supply-chain hardening) and documents its reasoning, but it
shows how things are built more than how they are run: nothing is deployed, and there is no
monitoring, no real-cloud deploy, no incident or postmortem.

## Options considered

1. **Keep the scope as written** (ADR-0008 phases, MLOps on the existing `recommendationservice`).
   The current `recommendationservice` is not a real ML system, so this means first building a toy
   model, which is weak signal.
2. **Drop the AI work to keep the project focused.** Considered and rejected: the US data, though
   soft, points to AI infrastructure as a growing area adjacent to DevOps, and the project's
   platform (CD, observability, rollback) is exactly its prerequisite.
3. **Reorder: finish the run-it story first, then add AI serving on the platform** (chosen).

## Decision

1. **Positioning:** a regulated-grade delivery, operations and AI-serving platform on AWS and EKS,
   aimed at US DevOps, platform and AI-infrastructure roles. The README leads with what runs and
   what it demonstrates; process artifacts (ADRs, journal) support it rather than lead.
2. **Phases** (Phase 1 unchanged in shape; 2 to 4 replace ADR-0008's):
   - **Phase 1, commit to running app:** CD with rollback by redeploying the previous digest, the
     budget alarm, one real-AWS deploy with evidence (logs, screenshots, teardown, cost note) and
     the negative trust test, threat model, a simple failure exercise, demo.
   - **Phase 2, operate it:** observability (metrics stack, dashboards), SLOs and alerts, an
     incident drill with a written postmortem, DORA metrics, GitOps with per-PR environments,
     policy-as-code, the golden-path workflow, the team access model.
   - **Phase 3, AI serving on the platform (LLMOps):** an open-weight model server on the
     cluster, model versions promoted through an evaluation gate in CI with canary and rollback,
     latency, cost and token metrics with alerts, autoscaling. CPU-friendly small models keep it
     free; GPU is not required to show the platform work.
   - **Phase 4, classic MLOps:** a real recommendation model with training and evaluation on PR,
     a registry, metrics-gated promotion and drift monitoring, built on Phase 3's platform.
   - **Optional stretch:** distributed tracing.
3. **Certifications** are not a project priority (opinion-only evidence, CKA rare in MLOps
   postings). OpenTofu is kept and described as Terraform-compatible, since postings say
   Terraform.
4. **Small additions worth doing** when convenient: `tofu test` for the modules, a small Python ops
   tool (Python appears in about two thirds of postings and is absent from the project), and a
   Floci upstream contribution (the existing external-validation goal).
5. **Relocation** is a career plan, not a repository concern. The visa route (sponsorship, or
   treaty-based options) is outside this repo and should be verified with immigration counsel;
   the repository's job is to evidence the skills.

## Rationale

The verified evidence is thin, so the decision leans on what is robust: the gaps the project has
are the ones the sources agree on, and the AI phases sit on top of the operational core rather than
competing with it. Ordering the core first means every later phase inherits real deployment,
monitoring and rollback.

## Consequences / trade-offs accepted

- The roadmap is long. Phases 3 and 4 are only worth doing on top of a working Phase 1 and 2, and
  can be cut after Phase 3 without losing the story.
- Phase 3 depends on a small model being servable cheaply; if CPU inference is too slow to
  demonstrate autoscaling and latency alerts, a short GPU run at the milestone is the fallback.
- Revisit after Phase 2: re-check current US postings for what they ask of 2-4 year candidates, and
  cut or reorder Phases 3 and 4 accordingly.
- Still undecided, and blocking the CD work: how a deploy identifies the current image per service
  under path-filtered builds (content-hash tags, a moving tag, or building everything), what gets
  deployed (the 11 base services, without the load generator), and how the milestone holds state
  (local state in one atomic job). To be settled in the CD design.
