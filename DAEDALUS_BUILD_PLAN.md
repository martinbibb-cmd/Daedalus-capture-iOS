# Daedalus Build Plan Projection

This is the Daedalus-capture-iOS projection of the canonical build plan. The
canonical authority lives in `Daedalus-contracts/DAEDALUS_BUILD_PLAN.md`.

## Shared Platform Direction

- Property is the root identity.
- Twin belongs to Property.
- Capture creates property-rooted Working Twins and Capture Sessions.
- Contracts define shared truth.
- Platform stores active Property, Twin, and import metadata.
- R2 stores package and media objects.
- Main imports, validates, explains, and renders evidence packs.
- AI may improve readability only; it is not source of truth.
- Users, billing, permissions, sync, and revenue models are deliberately deferred.

## Canon Projection

This repo follows the current Daedalus Canon as a Capture projection:

- Capture observes reality.
- Capture is CSI: physical evidence plus witness statements.
- Capture does not solve, analyse, recommend, rank, price, select, optimise, or decide.
- Capture uses additive and deductive reasoning only to improve observation quality.
- Capture maximises information gain, not evidence volume.
- Capture may ask the next most valuable question when the current evidence shows a capture gap.
- Capture preserves unknown, approximate, unresolved, contradicted, and fallback states.
- LLM extraction from transcripts is statement parsing only, not truth creation.
- Statement-derived data remains marked as statement-derived until reviewed or confirmed.

The canonical Manifesto, Laws, Constitution, and Philosophy Maintenance process remain upstream of this repo. This file is a local projection and must be refreshed when the canonical projection changes.

## Current Stage

Stage P0: Property-root Platform Foundation

Completed:

- property-root contracts
- Capture C3 property-root lifecycle
- Main P1/P2/D1 alignment
- Platform Property POC
- Platform Capture Package Import
- Platform Property Viewer
- Platform Property Dashboard v1

## Next Planned Tranches

These are planned, not implemented:

1. Live deploy verification
   - Confirm Cloudflare Worker routes.
   - Confirm D1 migrations applied remotely.
   - Confirm R2 write.
   - Import real Capture export.
   - View it in Platform Dashboard.
2. Main evidence-pack integration
   - Main can render an Evidence Pack from imported Platform data or stored package JSON.
   - Still no recommendations.
3. Capture upload handoff
   - Capture can export or share package to Platform import endpoint manually.
   - No full sync yet.
4. Data portability checkpoint
   - Confirm D1/R2 schema remains portable.
   - Export all property and import metadata as JSON.

## Repo Responsibility: Daedalus-capture-iOS

Owns:

- offline capture
- PropertyIdentity creation/selection
- WorkingTwin creation
- SurveyCaptureSession
- evidence capture
- spatial Twin review workflow
- v4 export package
- statement capture and statement-derived candidate fields when explicitly marked
- uncertainty, confidence, fallback, unresolved, and review state preservation

Must not own:

- cloud sync yet
- AI recognition
- AI truth creation
- recommendations
- ranking, scoring, optimisation, product selection, or pricing
- billing or users
- Main reasoning

## Capture Review Direction

Capture review is based on reconstructed reality, not metadata review. The
surveyor asks "Have I got the property right?" rather than "Is this marker
metadata correct?"

- Default review view is a top-down floor plan of the Working Twin.
- Future advanced review may use a raised, rotatable 3D model.
- Do not use a fixed cutaway house, side elevation primary view, or card/list-first review.
- The Twin remains visible while evidence is inspected.
- Captured objects are selected directly on the plan or model.
- Evidence expands from the selected object.
- Photos, voice notes, transcripts, confidence, and review status attach to the object.
- Unknown, unresolved, approximate, and fallback states are visible on the Twin.
- Review actions correct the reconstructed Twin.

Capture is CSI: it records physical evidence and witness statements, uses
additive and deductive reasoning, maximises information gain, and asks the next
most valuable question where possible. LLM transcript extraction is statement
parsing only, not truth creation.

## Deferred Explicitly

Do not implement yet:

- user accounts
- roles
- permissions
- billing
- subscriptions
- enterprise hierarchy
- sync engine
- AI extraction beyond statement parsing
- recommendations
- compliance or legal judgement
- solution analysis
- pricing, ranking, scoring, optimisation, product selection, or quote selection

## Anti-Drift Rules

- Any contract shape change must begin in Daedalus-contracts.
- Capture Swift mirror must be explicitly checked after contract changes.
- Main must validate package/import behaviour against shared contracts.
- Platform must validate API inputs against shared contracts.
- No repo may invent its own property-root semantics silently.
- Any cross-repo change must update this build-plan file.
- Capture docs and implementation must keep statement-derived data distinct from confirmed fact.
- Capture must prefer the next most valuable question over collecting repetitive low-value evidence.
- Capture must preserve uncertainty rather than hiding it behind defaults.

## Verification

Run before merging changes in this repo:

```sh
swift test
xcodebuild test
git diff --check
```

Run `swift test` from `DaedalusContracts`. Run `xcodebuild test` when an Xcode
scheme is available.
