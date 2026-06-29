# Capture Architecture Freeze

Daedalus Capture is a stable evidence collection platform for Main.

Capture records reality. Capture does not solve reality.

Capture is CSI. It records physical evidence and witness statements. It may
use additive and deductive reasoning to maximise information gain and ask the
next most valuable question where possible, but it must not turn observations
or statements into unearned truth.

## Scope

Capture owns:

- visits
- rooms and areas
- components
- observations
- photos
- voice notes
- continuous recordings
- transcripts
- spatial context
- evidence bundles
- local recovery state
- complete visit export packages

Capture keeps this data local-first, reviewable, exportable, and recoverable.

## Boundary

Capture must not:

- recommend products
- advise customers
- infer intent
- score opportunities
- rank options
- select quotes
- generate customer outputs
- convert passive observations into conclusions
- treat LLM transcript extraction as truth creation
- classify boilers, pumps, pipework, controls, or systems from RoomPlan
- infer system type
- suggest what an object is

Those responsibilities belong to Main.

## Operating Principle

Capture can record reality before it understands reality.

The capture loop is:

1. Start survey.
2. New room.
3. Capture the RoomPlan skeleton.
4. Snap, say it, mark it, measure it, or test it in place.
5. Keep scanning until the room can be represented.
6. Finish room.
7. Add the room to the Twin and retain location for stitching.
8. Move to the next room.
9. Complete survey.
10. Merge/export.

Incomplete, unmapped, uncertain, or passive observations are valid Capture data. They should be preserved rather than forced into a conclusion.

LLM transcript extraction is statement parsing only. A parsed transcript can
identify that someone said something; it cannot make the statement true.

## Capture v1 Survey Principle

Capture v1 is room-first. It is simple, stable, dumb, and surveyor-led.

RoomPlan is for a clean House skeleton: room outline, openings, boundaries, and
labelled geometry. It is not a systems classifier.

Photos, voice notes, transcripts, notes, measurements, manual markers, safety
notes, and test sheets attach to the current room, object, or session. Systems
evidence comes from that captured evidence. Main analyses it later.

V1 has no separate metadata review stage as its main quality gate. The surveyor
gets continuous confidence from a pull-over view of Twin So Far, Notes, and
Photos. Complete Survey is the final trust action: "Yes, this captured Twin
represents what I saw."

If room geometry is incomplete, Capture keeps scanning and shows a factual
completion message. It must not ask the surveyor to finish an unrepresentable
room.

## Handoff To Main

Main should receive the complete visit package:

- rooms
- components
- observations
- photos
- voice notes
- recordings
- transcripts
- spatial context
- evidence bundles

Capture should not filter out uncomfortable, uncertain, unmapped, or low-confidence material. Main can reason over the record; Capture preserves the record.
