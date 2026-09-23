# ADR-0017: Extend the project into a Well-Architected reference, with an architecture track

**Status:** accepted (extends [ADR-0010](0010-us-market-positioning-and-ai-phases.md); the phases of ADR-0008 and ADR-0010 stay, re-framed)
**Date:** 2026-09-23

## Context

The owner wants to add AWS Solutions Architect roles to the target: a project that follows and builds on AWS's
principles, with real reporting, discussion points that show understanding and the ability to move forward, and
skills and familiarity that carry into interviews. Every part of the project is open to change.

Evidence gathered, with its limits stated:

- A multi-agent research run (99 agents, 17 sources, 25 claims checked: **13 confirmed, 12 refuted**). It is thin.
  The confirmed claims come from prep-vendor blogs, one personal blog, one recruiting firm and a 2020 forum post.
  It has no AWS primary sources and no real job postings, and it did not answer role levels, experience bands,
  certification weight, or how recruiters view emulator-based work. What held up: the AWS SA interview loop is
  multi-stage and ends in an onsite that usually includes a presentation; the system design round is
  conversational, with requirements added live and trade-offs defended verbally (sample topics: a RAG system at
  scale, RTO/RPO and the DR spectrum); behavioral rounds use Amazon's 16 Leadership Principles; and emulator
  work has a ceiling (a Floci comparison says its tests cover tested SDK and IaC scenarios, not full AWS behavior).
- A direct check found that AWS's "Solutions Architect – 2026 (US)" posting is the **Associate SA early-career
  program**, which a search-tool summary says requires a graduation date between August 2024 and August 2026
  (medium confidence; the page itself returned 404 when fetched). The owner is therefore probably not eligible
  for that program, and partner, consultancy and ISV roles are an open question this evidence does not answer.
- AWS's own pages, which the structure below follows: the
  [Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/the-pillars-of-the-framework.html)
  has six pillars (operational excellence, security, reliability, performance efficiency, cost optimization,
  sustainability); the Well-Architected Tool is free but is an AWS Console service; the lens catalog includes
  Container Build, DevOps, Financial Services Industry, Generative AI, Machine Learning, Serverless Applications
  and Migration; and AWS's
  [migration strategies](https://docs.aws.amazon.com/prescriptive-guidance/latest/large-migration-guide/migration-strategies.html)
  are the 7 Rs, with AWS recommending rehost or replatform first and modernizing afterwards for large migrations.

What the project is today: strong evidence of building and operating (IaC, least-privilege IAM, GitOps, a
failure exercise with a postmortem, ADRs). What it lacks for an architect: a stated customer and requirements,
architecture views, a formal review against AWS's framework, cost and reliability designs, migration options,
and customer-facing material. Most of that is design work, not more infrastructure.

## Decision

1. **Positioning.** A Well-Architected reference: an AWS-shaped platform that is designed, reviewed, costed,
   built and operated, with the reasoning written down. Two proofs sit side by side: an architecture track (what
   should be built and why) and the engineering (it was built, run and broken on purpose). The DevOps depth stays
   the differentiator; the project does not become slides.
2. **A stated scenario.** A fictional customer with requirements, as an architect would gather them:
   a mid-size retailer moving its storefront from on-premises to AWS, with card payments in scope, availability
   and RTO/RPO targets, a budget, and a small team. It is clearly labelled fictional, and its assumptions are
   written down. Every design choice traces back to a requirement.
3. **An architecture track in `docs/architecture/`**, each item with an evidence label (below):
   requirements and constraints; architecture views (context, containers, AWS deployment, delivery flow, data
   flow, trust boundaries), as diagrams in code so they stay versioned; a **Well-Architected review** against all
   six pillars and the relevant lenses (Container Build, DevOps, Financial Services Industry, and Generative AI
   when Phase 3 starts), with a findings register; a reliability and disaster-recovery design (RTO/RPO tiers,
   multi-AZ and multi-region options, cost per tier); a cost model with real pricing; migration options using
   the 7 Rs, applied to the scenario; security and compliance (the threat model, plus a control mapping that
   says it is a mapping, not a certification); an AI architecture (Bedrock against self-hosted serving on EKS);
   and a governance design (multi-account layout and guardrails).
4. **Review, fix, review again.** The first review is honest and will find real risks in this project (a single
   node, no TLS, an unsigned webhook, no observability yet). Each finding is tied to a milestone. A second review
   after Phase 2 shows what changed. The movement between the two is the artifact.
5. **Customer-facing and interview material** are first-class: a one-page executive summary, a readout of the
   review, discovery questions, and an interview kit in which every decision maps to a pillar, its alternatives,
   and what would change on real AWS. Stories are drawn only from things that actually happened here, with links
   (for example, the smee signature limitation found and corrected, the Floci restart failures, the failure drill).
6. **Evidence labels, everywhere.** Each claim in the track is marked **designed** (reasoned, not built),
   **verified on Floci** (built and run on the emulator, with its limits stated), or **verified on real AWS**
   (none yet). Nothing is presented as production-proven. Real AWS stays deferred by ADR-0012, and the review
   names which findings only real AWS can settle.
7. **Sequence, by dependency.**
   1. The scenario, requirements and architecture views (everything else hangs off them).
   2. Review v1 and its findings register.
   3. Close the remaining Phase 1 items (the pre-merge check, the threat model as part of the security document,
      the demo).
   4. The cost model and the reliability and DR design.
   5. Migration options.
   6. Phase 2 (operate it), then review v2.
   7. The AI architecture and Phase 3.
   8. The interview kit grows throughout, not at the end.
8. **Phases.** Phases 1 to 3 stay, now read as evidence for pillars: Phase 1 for security and operational
   excellence, Phase 2 for reliability and operational excellence, Phase 3 for the Generative AI lens. Phase 4
   (classic MLOps) becomes an optional stretch, because breadth of design matters more here than depth in one
   more system.

## Options considered

- **Keep the DevOps and platform focus only** (ADR-0010): valid, and the evidence for it is untouched, but it
  does not serve the owner's stated wish to explore Solutions Architect roles.
- **A separate architecture repository:** clean separation, but it would split a portfolio whose strength is that
  the design is backed by a running system with recorded decisions.
- **More infrastructure instead of design work:** the gaps are architectural artifacts, and more running
  systems would not close them.
- **Convert the project fully into a case study:** loses the engineering proof, which is what distinguishes this
  from a slide deck.

## Consequences / trade-offs accepted

- The evidence for what US employers want from an SA with 2 to 3 years of experience is still thin. The role
  landscape (AWS, partner, consultancy, ISV) and how much certifications weigh are open, and this decision does
  not depend on them. A follow-up should tally real postings.
- The scenario is fictional, so it shows the method, not customer experience. Saying so plainly is part of the
  honesty rule.
- More documents to keep true. The evidence labels and the findings register exist to keep them honest, and
  ADRs remain the place for decisions.
- The Well-Architected Tool needs an AWS account (free). The review is done in the project's own documents first,
  in the framework's terms, and entering it into the Tool is optional and a later, small step.
- Scope grows. The sequence is ordered so each step is useful on its own and the project can stop at any point.
