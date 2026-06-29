# Survey Workflow Redesign Review

## Objective

Daedalus Capture should feel like a survey tool, not an ARKit console. LiDAR, spatial capture, evidence anchoring, review, and merge remain core. The redesign changes what the surveyor sees first: one survey journey instead of separate implementation workflows.

Capture review is not metadata review. The surveyor is reviewing reconstructed
reality and asking "Have I got the property right?"

## Current Workflow Review

The previous Property Twin screen exposed the internal workflow directly:

- Twin Overview
- AR Capture
- Capture Lite
- Component Evidence
- Review
- Evidence Timeline
- Merge Twin

Those are valid system capabilities, but they make the surveyor choose the app subsystem before doing the job. The live capture screen also surfaced AR-oriented ideas such as placement anchors, captured surfaces, geometry, and scan session status. That made the activity feel like operating a scanner rather than surveying a property.

## Architectural UI Leaks

- `AR Capture` named the technology instead of the user activity.
- `Capture Lite`, `Component Evidence`, and `Evidence Timeline` made evidence collection feel like separate workflows.
- Live status labels exposed anchors, fallback placement, geometry, and surface counts.
- The main screen presented review and merge at the same level as capture, which obscured the intended flow.
- The old `Mark` action described a generic implementation event rather than the surveyor intent: pay attention here.

## Implemented Thin Slice

- Reworked `PropertyTwinHomeView` around a single primary action: `Start Survey`, `Continue Survey`, or `Open Survey`.
- Moved lower-level record tools behind `Survey Record`, reducing the first-screen workflow to Survey, Review, Merge.
- Made review a survey checkpoint rather than a hard exit: live survey now enters `Pause & Review`, and the review screen offers `Resume Survey`.
- Renamed the live capture surface around survey language:
  - `Survey in progress`
  - `Snapshot`
  - `Note`
  - `Focus`
  - `Safety`
  - `Review`
- Preserved the existing spatial AR session and evidence anchoring.
- Started the existing `ContinuousVisitRecordingService` when the live survey starts and stopped it when the survey moves to review.
- Kept the internal `.mark` evidence kind for compatibility, but changed its user-facing title and default label to `Focus`.
- Updated tests so the expected language is survey intent rather than AR/tool implementation.

## Spatial Review Direction

The review workspace should default to a top-down floor plan of the
reconstructed Twin. The Twin remains visible while the surveyor checks the
property. Captured objects are selected directly on the plan; evidence expands
from the selected object.

Future advanced review may add a raised, rotatable 3D model. The review
direction explicitly excludes a fixed cutaway house visual, side elevation as
the primary view, and card/list-first review. Photos, voice notes, transcripts,
confidence, and review state attach to the selected object. Unknown,
unresolved, approximate, and fallback states must be visible on the Twin.
Review actions correct the reconstructed Twin.

Capture is CSI. It records physical evidence and witness statements, uses
additive and deductive reasoning, maximises information gain, and asks the next
most valuable question where possible. LLM transcript extraction is statement
parsing only, not truth creation.

## Improved Workflow

Property Twins
↓
Open Existing Twin or Create New Twin
↓
Start Survey
↓
Survey In Progress
↓
Pause & Review
↓
Resume Survey or Review Survey
↓
Merge Twin

The secondary record remains available, but it no longer competes with the primary survey action.

## What Remains Unresolved

- Focus Mode is currently a survey intent marker, not a true fidelity-control path into ARKit capture configuration.
- The live spatial visual is still camera/mesh based; it has not yet been simplified into a MagicPlan-like room/wall/opening abstraction.
- Continuous audio recording is now started with the survey, but live transcription and transcript-to-evidence review remain the existing placeholder pipeline.
- Review still uses evidence-group terminology in places and should be reworked into a spatial Twin review workspace.
- Merge is still a separate screen rather than the final step of a guided review completion path.
- Resume restarts capture, but it does not yet preserve a long-running AR world map across the review checkpoint.

## Why This Improves Real Surveying

The surveyor no longer has to choose between AR capture, component evidence, evidence timeline, and review before beginning. The first action is to start the survey. During the survey, they can walk, talk, take snapshots, flag safety concerns, and tell the software to focus on an important area. Review now behaves like a pause to check the reconstructed property, with an explicit route back into the survey. The app continues to capture space and evidence in the background, while review and merge stay intact as the quality gate before the Property Twin is updated.
