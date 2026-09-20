# ADR-0001: Use an existing open-source app as the target codebase

**Status:** accepted
**Date:** 2026-08-22

## Context
This project's goal is to build platform/infra/CI-CD/MLOps skill, not application code. Two
paths: write a sample app from scratch, or fork an existing one and build tooling around it.

## Options considered
1. **Write a sample app from scratch.**
   - Pros: full control, no attribution needed.
   - Cons: a large share of the effort goes into app logic rather than platform work, and it's
     easy to unconsciously avoid hard multi-service problems by not building them into the app
     in the first place.
2. **Fork Google's Online Boutique (`microservices-demo`).**
   - Pros: real polyglot complexity (Go, Java, .NET, Node, Python) forces genuine multi-language
     CI/CD and orchestration problems; Apache-2.0, forkable; well-known enough that reviewers
     immediately understand the baseline and can focus on judging the added platform layer;
     already includes a `recommendationservice` (Python) as a natural MLOps seam.
   - Cons: need to be explicit in the README about what's original work vs. upstream, to avoid
     any appearance of claiming the app itself as original.
3. **Sock Shop** (older Weaveworks polyglot demo).
   - Pros: simpler, smaller.
   - Cons: less actively maintained, less name recognition.

## Decision
Fork Google's Online Boutique (`microservices-demo`) as the target application.

## Rationale
The point of this project is to demonstrate judgment about multi-service, multi-language
platform and infra problems — a real, already-complex app forces those problems to exist
rather than letting them be avoided. Explicitly scoping "app code is Google's, platform code
is mine" in the README is a stronger signal than pretending to have written the app, because
it shows an understanding of the actual skill boundary being demonstrated.

## Consequences / trade-offs accepted
- README must clearly attribute the base app and scope original contributions.
- Some early time goes into understanding the existing app's structure before building on it.
- Revisit only if the polyglot spread turns out to be more friction than value (unlikely given
  the goals — the polyglot-ness is a feature here, not a bug).
