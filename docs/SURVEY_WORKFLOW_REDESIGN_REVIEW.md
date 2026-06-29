# Survey Workflow Redesign Review

## Objective

Daedalus Capture should feel like a survey tool, not an ARKit console. RoomPlan, spatial capture, evidence anchoring, and merge remain core. The redesign changes what the surveyor sees first: one room-first survey journey instead of separate implementation workflows.

Capture v1 has no separate metadata review stage as its main quality gate. The
surveyor builds confidence continuously by seeing the Twin so far, notes so
far, and photos so far during capture.

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
- The main screen presented review and merge at the same level as capture, which obscured the intended room-first flow.
- The old `Focus` action implied a separate scan path that could replace or end the room scan.

## Implemented Thin Slice

- Reworked `PropertyTwinHomeView` around a single primary action: `Start Survey`, `Continue Survey`, or `Open Survey`.
- Moved lower-level record tools behind `Survey Record`, reducing the first-screen workflow to Survey and Complete Survey.
- Removed `Pause & Review` as a primary live workflow.
- Replaced live review navigation with an in-capture pull-over: `Twin So Far`, `Notes`, and `Photos`.
- Renamed the live capture surface around survey language:
  - `Survey`
  - `Snapshot`
  - `Voice`
  - `Marker`
  - `Finish Room`
  - `Safety`
  - `Record`
- Preserved the existing spatial AR session and evidence anchoring.
- Started the existing `ContinuousVisitRecordingService` when the live survey starts and stopped it when the survey completes.
- Kept the internal `.mark` evidence kind for compatibility, but changed its user-facing title and default label to `Marker`.
- Updated tests so the expected language is survey intent rather than AR/tool implementation.

## Capture v1 Direction

The survey workflow is:

- Start survey.
- New room.
- RoomPlan captures the room skeleton.
- Photos, voice, notes, measurements, manual markers, safety notes, and existing water/electrical test sheets attach to the current room.
- Finish room only when geometry is complete enough.
- If geometry is incomplete, keep scanning and show a factual completeness message.
- Add room to the Twin and retain location for stitching.
- Move to the next room.
- Complete survey.
- Merge/export.

RoomPlan is for a clean House skeleton. It must not be presented as a classifier
for boilers, pumps, pipework, controls, or other systems. Systems evidence
comes from photos, voice, manual markers, measurements, and tests. Optional
ARKit detail capture can happen later against existing room/object geometry
when extra fidelity is needed.

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
New Room
↓
RoomPlan Room Skeleton
↓
Evidence Attached In Place
↓
Finish Room / Next Room
↓
Complete Survey
↓
Merge / Export

The secondary record remains available, but it no longer competes with the primary survey action.

## What Remains Unresolved

- Optional ARKit detail capture still exists internally as a fidelity-control path, but it is not a primary v1 room workflow.
- The live spatial visual is still camera/mesh based; it has not yet been simplified into a MagicPlan-like room/wall/opening abstraction.
- Continuous audio recording is now started with the survey, but live transcription and transcript-to-evidence review remain the existing placeholder pipeline.
- Some secondary admin/export screens still use review terminology for legacy package compatibility.
- Merge is still a separate screen rather than the final step of a guided complete-survey path.

## Why This Improves Real Surveying

The surveyor no longer has to choose between AR capture, component evidence, evidence timeline, and review before beginning. The first action is to start the survey. During the survey, they scan a room, take snapshots, leave voice notes, mark positions, measure, run existing test sheets, and check the Twin so far without leaving capture. Complete Survey is the final trust action: "Yes, this captured Twin represents what I saw."
