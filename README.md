# Daedalus Scan

Canonical iOS field-capture application for the Daedalus platform.

## Purpose

Daedalus Scan captures structured survey data, photos and voice notes for site visits. It does not generate recommendations, quotations, pricing or customer advice.

## Architecture

- `DaedalusScanApp` application target
- `DaedalusScanCore` framework target for capture flows and persistence
- iOS only
- XcodeGen is the source of truth
- MVVM presentation flow
- `DaedalusContracts` local package placeholder (temporary until switched to canonical `Daedalus-contracts` repository dependency)
- JSON persistence for local-first storage

## Capture-only boundaries

Daedalus Scan remains strictly capture-only:
- captures visit metadata, structured survey answers, photos and voice notes
- does not include LiDAR capture yet
- does not include recommendations
- does not include quotations
- does not include pricing
- does not include heat-loss analysis
- does not include customer advice
- does not include sales logic

## Known non-goals (MVP)

- no LiDAR yet
- no recommendations
- no pricing
- no heat-loss
- no customer advice

## Features in this scaffold

- Visit list
- Create visit workflow
- Room list workflow
- System component capture workflow
- Structured survey questions per room
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

## MVP manual test script (iPhone)

Use this script on a physical iPhone after running `./bootstrap.sh` and launching `DaedalusScanApp`.

1. Create a visit with reference `MVP-SMOKE-001`.
2. Add one additional room.
3. Add three components: one boiler, one flue, and one other component kind.
4. In a room, attach one photo, one voice note, and one text note.
5. In a component, attach one photo, one voice note, and one text note.
6. Set section statuses (for example boiler = Present, flue = Not Accessible).
7. Set review status + notes on:
   - room
   - room survey response
   - room evidence item
   - component
   - component evidence item
8. Export the visit package and verify the export completes.
9. Import the exported package and choose **Keep Both** when prompted for conflict resolution.
10. Re-import the same package and choose **Replace Existing Visit** when prompted.
11. Confirm the visit list and detail screens still open correctly after both conflict paths.
