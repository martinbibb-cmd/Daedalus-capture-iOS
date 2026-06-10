# Daedalus Capture

Canonical iOS Digital Twin editor for the Daedalus platform.

## Constitutional Boundary

This repository is governed by the [Daedalus Platform Constitution v1.2](docs/constitution/DAEDALUS_CONSTITUTION_v1.2.md).

Daedalus exists to create, maintain, and explain living Digital Twins of homes and their technical systems.

This repo must obey:

- Reality → Analysis → Explanation
- No automated recommendation logic
- No hidden quoting or sales logic
- Module boundary rules defined in the constitution

## Purpose

Daedalus Capture creates and maintains Property Twins representing real properties.

The product is the Property Twin. Capture is the editor. Main is the separate application that explains the Property Twin.

Capture records reality. Main explains reality.

The app is capture-only. It records what is physically present, where it was observed, why it matters, and what evidence supports it. It does not generate recommendations, quotations, pricing, heat-loss outputs, simulations, scenarios, shading analysis, EPC interpretation, smart-meter interpretation, or customer advice.

## Product direction

Daedalus Capture v1 is Property Twin-first, spatial-first, and evidence-first:

- open a Property Twin and land in the lifecycle workflow
- pull the authoritative twin into a Working Twin
- walk the property
- scan geometry, boundaries, openings, and labelled areas for the House Twin
- identify system components in position for the System Twin
- use Capture Lite on devices or visits where AR capture is unavailable
- capture occupancy, behaviour, constraints, and human observations for the Home Twin
- attach photos, voice notes, documents, labels, and text evidence to captured reality
- correct evidence bundle details before merge when reality is clarified
- preserve spatial placement or explicit fallback state when anchoring is unavailable
- locate captured components from Twin Overview markers
- review the evidence timeline and merge summary before updating the authoritative twin
- review, clarify, confirm, and merge local changes into the authoritative twin

Property Twin list, summaries, and detail forms remain available as secondary fallback/admin surfaces. They are not the main capture journey.

## The three twins

- House Twin: where things exist. Geometry, boundaries, openings, volumes, structural features. Rooms are labels; geometry is truth.
- System Twin: what exists. Heating, hot water, electrical, generation, storage, cooling, ventilation, and controls. Components are primary; relationships can be added over time.
- Home Twin: why things matter. Occupancy, behaviour, context, requirements, constraints, and human observations. Capture records observations; it does not generate explanations.

## Property Twin lifecycle

Properties are managed internally as repositories. Users see and work with Property Twins.

- Pull Twin: download the authoritative twin and create a Working Twin.
- Capture: observe reality and add photos, voice notes, geometry, components, and context.
- Commit: create a local change set.
- Review: review added, removed, and updated items.
- Clarify: resolve uncertainty.
- Recapture: capture additional evidence.
- Confirm Captured Evidence: confirm evidence review state without generating conclusions.
- Merge Twin: update the authoritative twin and generate history automatically.

Working Twin state is visible throughout the app:

- Pulled
- Capturing
- Has unreviewed evidence
- Ready to merge
- Merged

Capture warns before leaving unmerged work, pulling over local changes, or merging while evidence still needs review.

## Trust model

Trust comes from evidence. The app records evidence and review state, but humans remain authoritative. Automation may assist, but nothing may create facts without human confirmation.

Evidence trust order:

1. Reality
2. Photos
3. Documents
4. Measurements
5. Human observations
6. Twin data

## Architecture

- `DaedalusScanApp` application target
- `DaedalusScanCore` framework target for capture flows and persistence
- iOS only
- XcodeGen is the source of truth
- MVVM presentation flow
- `DaedalusContracts` source compiled directly into `DaedalusScanCore` (no SPM boundary for the app build; `DaedalusContracts/Package.swift` is kept for standalone `swift test` validation only)
- JSON persistence for local-first storage
- twin packages export Property Twin metadata, scanned areas, spatial objects, evidence, review state, lifecycle state, and spatial fallback metadata

## Core capture model

Export/import packages are expected to represent:

- Property Twin metadata
- scanned rooms/areas
- spatial heating/hot-water objects
- object kind/type
- approximate position and anchor metadata when available
- photos
- voice notes
- text notes
- review status
- spatial confidence
- fallback state when spatial capture fails
- evidence timeline entries derived from captured evidence
- merge summary counts for added components, edited evidence, deleted evidence, confirmed evidence, and evidence still needing review

## Features in this scaffold

- Property Twin list and create Property Twin entry point
- Property Twin home with version, last merged state, and Pull Twin action
- Working Twin lifecycle path: Pull Twin, Twin Overview, AR Capture, Component Evidence, Review, Merge Twin
- Immediate transition into the Property Twin lifecycle when a Property Twin is opened or created
- Twin Overview with component markers, location labels, review state, merge state, and marker filters
- AR Capture and Capture Lite evidence capture paths
- Component Evidence with evidence bundle editing and deletion before merge
- Evidence Timeline per Property Twin and component
- Review with evidence cards grouped by component
- Merge Summary with current version to next version preview
- Camera-first capture shell for object/area capture
- Spatial fallback metadata on rooms/areas and components
- Secondary fallback detail panels for areas and objects
- Photo capture attachment
- Voice note attachment
- Export/import visit packages

## Getting started

1. Run the fresh-clone bootstrap:
   ```bash
   ./bootstrap.sh
   ```
2. Open the generated `DaedalusScan.xcodeproj` in Xcode.
3. Select the `DaedalusScanApp` scheme, choose a physical iPhone or iPad target and run.

## Fresh-clone bootstrap details

`bootstrap.sh` runs these commands:

```bash
xcodegen generate
cd DaedalusContracts && swift test
```

If you prefer to run manually:

1. Install XcodeGen on macOS (`brew install xcodegen`).
2. Generate the project from the checked-in spec:
   ```bash
   xcodegen generate
   ```
3. Validate the local contracts package:
   ```bash
   cd DaedalusContracts
   swift test
   ```
4. Open the generated `DaedalusScan.xcodeproj` in Xcode, select `DaedalusScanApp`, choose a physical iPhone or iPad and run.

Generated Xcode project artefacts are intentionally excluded from source control.

## Shared contracts tests

The shared contract package can be validated from a fresh clone with:

```bash
cd DaedalusContracts
swift test
```

## Manual smoke script (iPhone or iPad)

Use this script on a physical iPhone after running `./bootstrap.sh` and launching `DaedalusScanApp`.

1. Create a Property Twin with reference `SPATIAL-SMOKE-001`.
2. Confirm the Property Twin opens to the Property Twin home screen with version and last merged state.
3. Tap **Pull Twin** and confirm the lifecycle shows a Working Twin state.
4. Open **Twin Overview** and confirm House, System, and Home Twin summaries are visible.
5. Open **AR Capture** and capture a scanned area from the Area target.
6. Capture at least two spatial objects: boiler and one additional object kind.
7. Open **Capture Lite** and add a component with a picture, Voice Note, component type, and area/location.
8. Open **Twin Overview** and confirm component markers show type, area/location, review state, and merged/unmerged state. Test the marker filters.
9. Tap a marker and confirm it opens the correct **Component Evidence** screen.
10. Edit an evidence bundle field such as component type, area/location, geometry ID, approximate position, Voice Note transcript, or picture label. Confirm the edited evidence returns to needs review.
11. Delete a captured evidence bundle and confirm it is removed from **Review**.
12. Open **Evidence Timeline** and confirm captured date/time, evidence type, component, spatial context, and review state are visible.
13. Open **Review**, confirm captured evidence, and verify the review state changes visibly.
14. Open **Merge Twin** and confirm the Merge Summary shows added components, edited evidence, deleted evidence, confirmed evidence, evidence still needing review, and current version to next version.
15. Merge the twin and confirm the version increments and last merged date is recorded.
16. Export the twin package and verify the export completes.
17. Import the exported package and choose **Keep Both** when prompted for conflict resolution.
18. Re-import the same package and choose **Replace Existing Property Twin** when prompted.
19. Confirm the imported Property Twin still opens into the lifecycle flow and that evidence, timeline, markers, and spatial metadata remain visible.
