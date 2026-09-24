# ADR-0018: The scenario is one engagement with a card-payments retailer

**Status:** superseded by [ADR-0021](../0021-project-purpose-scenario-and-scope.md) (consolidated 2026-09-24; kept as the record of how the decision evolved)
**Date:** 2026-09-24

## Context

ADR-0017 needs a fictional customer so every design choice traces back to a requirement. Two candidates were on
the table: a mid-size retailer that takes card payments, or a regulated bank's storefront. The market check of
2026-09-24 ([research](../../docs/research/2026-09-24-sa-market-and-project-reality-check.md)) found regulated or
compliance work in 5 of 8 real postings, migration in 4 of 8, and written decision records in 6 of 8. The owner
comes from a regulated bank, so compliance is where they can speak from experience.

## Options considered

1. **A mid-size retailer taking card payments.**
   - Pros: fits Online Boutique as it is (a shop with checkout and payment services); PCI DSS gives a real,
     well-documented compliance frame; a retailer migrating to AWS is a common partner-consultancy engagement.
   - Cons: PCI DSS is large; the project can only map controls, not be assessed.
2. **A regulated bank's storefront.**
   - Pros: closest to the owner's day job.
   - Cons: a bank does not run a consumer shop, so the app and the story do not match; heavier regulation
     (for example, operational resilience rules) that a portfolio cannot honestly show.
3. **No scenario, a generic reference platform.**
   - Pros: less to write.
   - Cons: nothing to trace decisions back to, which is the point of an architect's work.

## Decision

The customer is a **fictional mid-size online retailer that takes card payments** and is moving its storefront to
AWS. Today the storefront runs on-premises, and one newer feature, the shopping assistant, runs on Google Cloud;
both move to AWS (the assistant by replatforming, [ADR-0019](0019-scope-cut-and-assistant-replatform.md)). The project is written as **one engagement**: discovery and requirements, design, Well-Architected review,
build, operate, a deliberate failure, and a second review. **PCI DSS** is the compliance frame, used as a control
mapping, never as a claim of compliance.

## Rationale

It matches the app, so no invented features are needed. It is the kind of work AWS partners sell (migration plus
compliance), which is the realistic next employer for the owner. It lets the owner's regulated-industry
background show through a frame (PCI DSS) that is public and well documented. A single engagement also gives the
many documents one storyline, which is easier to present in an interview than a list of artefacts.

## Consequences / trade-offs accepted

- The customer is fictional, so the project shows the method, not client experience. The docs say so.
- Payment handling in Online Boutique is a mock. The design will scope card data out of the platform (a hosted
  payment provider), which is also what a real retailer would usually do to shrink PCI scope. That choice is a
  design decision to explain, not a gap to hide.
- The customer's targets (availability, RTO/RPO) and budget are set in `docs/architecture/00-requirements.md`, not
  here. The customer's budget is fictional and has nothing to do with the owner's own spend (ADR-0020).
- Revisit if a later market check shows a different domain fits the target roles better.
