# Daedalus Scan

Canonical iOS field-scanning application for the Daedalus platform.

## Constitutional Boundary

This repository is governed by the [Daedalus Platform Constitution v1.2](docs/constitution/DAEDALUS_CONSTITUTION_v1.2.md).

Daedalus exists to create, maintain, and explain living Digital Twins of homes and their technical systems.

This repo must obey:

- Reality → Analysis → Explanation
- No automated recommendation logic
- No hidden quoting or sales logic
- Module boundary rules defined in the constitution

## Purpose

Daedalus Scan captures the job by walking the property with the camera, scanning rooms/areas, identifying heating and hot-water objects in space, and attaching evidence to those spatial objects.

The app is capture-only. It records what is physically present, where it was observed, and how confident the capture is. It does not generate recommendations, quotations, pricing, heat-loss outputs, or customer advice.

## Product direction

Daedalus Scan V2 is spatial-first and camera-first:

- open a visit and land in live capture
- walk the property
- scan rooms/areas
- identify heating and hot-water objects in position
- attach photos, voice notes, and text evidence to those captured objects
- preserve spatial placement or explicit fallback state when anchoring is unavailable
- export the structured job package for downstream reasoning in Mind

Visit list, summaries, and detail forms remain available only as secondary fallback/admin surfaces. They are not the main survey journey.

## Architecture

- `DaedalusScanApp` application target
- `DaedalusScanCore` framework target for capture flows and persistence
- iOS only
- XcodeGen is the source of truth
- MVVM presentation flow
- `DaedalusContracts` source compiled directly into `DaedalusScanCore` (no SPM boundary for the app build; `DaedalusContracts/Package.swift` is kept for standalone `swift test` validation only)
- JSON persistence for local-first storage
- visit packages export visit metadata, scanned areas, spatial objects, evidence, review state, and spatial fallback metadata

## Core capture model

Export/import packages are expected to represent:

- visit metadata
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

## Features in this scaffold

- Visit list and create visit entry point
- Immediate transition into live capture when a visit is opened or created
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
3. Select the `DaedalusScanApp` scheme, choose a physical iPhone target and run.

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
4. Open the generated `DaedalusScan.xcodeproj` in Xcode, select `DaedalusScanApp`, choose a physical iPhone and run.

Generated Xcode project artefacts are intentionally excluded from source control.

## Shared contracts tests

The shared contract package can be validated from a fresh clone with:

```bash
cd DaedalusContracts
swift test
```

## Manual smoke script (iPhone)

Use this script on a physical iPhone after running `./bootstrap.sh` and launching `DaedalusScanApp`.

1. Create a visit with reference `SPATIAL-SMOKE-001`.
2. Confirm the visit opens directly into live capture and auto-launches the camera.
3. Capture a scanned area from the Area target.
4. Capture at least three spatial objects: boiler, flue, and one additional object kind.
5. Attach photo, voice, and text evidence during capture.
6. Open the fallback detail panels and confirm each captured area/object shows spatial state and confidence metadata.
7. Mark at least one object or evidence item as needing review.
8. Export the visit package and verify the export completes.
9. Import the exported package and choose **Keep Both** when prompted for conflict resolution.
10. Re-import the same package and choose **Replace Existing Visit** when prompted.
11. Confirm the imported visit still opens into live capture and that the fallback detail panels preserve spatial metadata.
