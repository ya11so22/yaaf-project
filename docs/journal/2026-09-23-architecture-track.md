# 2026-09-23: Re-scoping toward a Well-Architected reference

**Phase:** direction (all phases)
**Related ADRs:** [ADR-0017](../../adr/0017-well-architected-architecture-track.md), extends [ADR-0010](../../adr/0010-us-market-positioning-and-ai-phases.md)

## What happened

The owner asked whether the project could support Solutions Architect roles, and then chose to extend it toward a
project that follows and builds on AWS's principles, with real reporting, discussion points that show
understanding, and skills that carry into interviews. Every part was declared open to change.

A deep-research run (99 agents, 17 sources, 25 claims: 13 confirmed, 12 refuted) was thin: the confirmed claims are
about the AWS interview loop, from prep-vendor blogs, with no AWS primary sources and no real job postings, and it
did not answer role levels, experience bands, certification weight, or how recruiters view emulator work. A direct
check found AWS's "Solutions Architect - 2026 (US)" posting is the Associate SA early-career program, which a
search-tool summary says requires a graduation date between August 2024 and August 2026, so the owner is probably
not eligible for it (medium confidence; the page returned 404 when fetched). AWS's own pages were then fetched for
the structure: six pillars, a free Well-Architected Tool (an AWS Console service), the lens catalog (Container
Build, DevOps, Financial Services Industry, Generative AI, Machine Learning, Serverless Applications, Migration)
and the 7 Rs of migration, with AWS's advice to rehost or replatform first and modernize afterwards.

ADR-0017 records the decision: an architecture track in `docs/architecture/` around a stated, fictional customer;
a Well-Architected review, fixes and a second review; cost, reliability, migration, security, AI and governance
designs; customer-facing and interview material drawn only from things that happened here; evidence labels on
every claim (designed, verified on Floci, verified on real AWS); Phase 4 demoted to an optional stretch.

## Why

The gaps for an architect are design artifacts, not more infrastructure. The running system is the proof that the
design can be built, and the design is what turns a build into an architect's work.

## Verification

Documentation only. The AWS facts were read from AWS's own pages; the market claims are marked as thin.

## Next

The scenario and requirements, then the architecture views, then review v1. Beside that, the Phase 1 close-out
(the pre-merge check, the threat model, the demo) and a tally of real US Solutions Architect postings to replace
the thin evidence.
