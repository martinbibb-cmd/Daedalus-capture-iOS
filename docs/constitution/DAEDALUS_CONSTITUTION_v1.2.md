Status: FROZEN
Version: 1.2.0
Classification: Constitutional Engineering & Platform Foundation

# Daedalus Platform Constitution & Architecture Specification v1.2.0

Any architectural change that alters Reality → Analysis → Explanation, the Three Twin Model, the Digital Twin lifecycle, or the Capture / Contracts / Main boundaries requires an explicit constitutional amendment.

## Core Thesis

The Digital Twin is the product.

Daedalus exists to create, maintain, and explain living Digital Twins of homes and their technical systems.

The platform must obey:

Reality → Analysis → Explanation

It must never become:

Reality → Analysis → Recommendation

Daedalus may explain consequences, constraints, scenarios, services delivered, trade-offs, and behaviours. It must not recommend choices, rank options, score suitability, select products, select manufacturers, create hidden quotes, or optimise for sales conversion.

## Three Twin Model

Daedalus models the home through three related twins:

- House Twin: where things exist.
- System Twin: what exists.
- Home Twin: why it matters.

The House Twin records spatial reality: site, structure, spaces, rooms, areas, fabric, access, and physical location.

The System Twin records technical reality: components, systems, services, relationships, capacities, controls, electrical infrastructure, ventilation, heat, cooling, hot water, generation, storage, and major loads.

The Home Twin records lived reality: occupancy, service needs, constraints, experiences, usage patterns, vulnerability, preferences stated as context, and why technical facts matter.

The twins are living assets. They are created, verified, updated, and explained over time.

## Digital Twin Lifecycle

Daedalus must support a lifecycle in which facts and components may be:

- Observed
- Installed
- Modified
- Serviced
- Repaired
- Replaced
- Retired
- Verified
- Not verified
- Contradicted by later evidence

Previous states are not silently overwritten. A changed reality is represented as an explicit change in the twin with provenance, evidence, time, and confidence.

## Evidence, Provenance, and Uncertainty

Significant facts must be traceable to evidence or explicitly marked as unresolved.

Facts should preserve:

- Source
- Evidence references
- Observation time
- Observer or capture method
- Confidence
- Unknown, approximate, and unresolved states
- Audit trail or integrity ledger where applicable

Unknown is a valid state. Approximate is a valid state. Unresolved is a valid state. The system must not replace uncertainty with hidden defaults to make analysis easier.

Captured evidence is source material. Derived outputs must be stored separately from captured evidence.

## Module Boundaries

### Capture

Capture observes reality.

Capture may:

- Record field evidence
- Record observations
- Record measurements
- Record spatial context
- Record confidence and uncertainty
- Package observed reality for Contracts and Main

Capture must not:

- Analyse
- Simulate
- Score
- Rank
- Recommend
- Price
- Select products
- Select manufacturers
- Judge suitability
- Produce sales logic

### Contracts

Contracts defines reality.

Contracts may:

- Define schemas
- Define package shapes
- Define observations
- Define evidence references
- Define provenance and confidence structures
- Define lifecycle and relationship structures
- Validate declarative integrity

Contracts must not:

- Simulate
- Calculate business outcomes
- Recommend
- Rank
- Score
- Price
- Select products
- Select manufacturers
- Encode sales workflows

### Main

Main explains reality.

Main may:

- Import twin packages
- Preserve evidence and provenance
- Derive analytical outputs
- Run physical or service models
- Compare consequences and scenarios
- Explain outcomes, constraints, behaviours, and trade-offs

Main must not:

- Capture evidence
- Mutate captured evidence
- Hide uncertainty
- Recommend choices
- Rank options
- Score suitability
- Select products or manufacturers
- Create hidden quoting, pricing, lead-generation, or sales-conversion logic

## Recommendation Boundary

The following concepts are constitutionally sensitive and must not cross module boundaries as automated decision logic:

- Recommendation
- Best option
- Preferred option
- Ranking
- Scoring
- Suitability
- Priority as prescription
- Product selection
- Manufacturer selection
- Quote selection
- Sales conversion

Neutral language is preferred:

- Outcome
- Consequence
- Scenario
- Service delivered
- Constraint
- Trade-off
- Behaviour
- Evidence strength
- Confidence

## Constitutional Change Control

This document is frozen as the Daedalus v1.2 constitutional baseline.

Any change that alters the core axiom, the Three Twin Model, the Digital Twin lifecycle, or the Capture / Contracts / Main boundaries must be proposed as a constitutional amendment before implementation.

Implementation PRs may align code to this constitution. They must not rewrite the constitution to fit implementation convenience.
