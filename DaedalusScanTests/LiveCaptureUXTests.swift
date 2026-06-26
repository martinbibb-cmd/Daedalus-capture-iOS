import XCTest
@testable import DaedalusScanCore

@MainActor
final class LiveCaptureUXTests: XCTestCase {
    func testLiveMarkCreatesUnclassifiedBookmark() throws {
        let harness = try makeHarness()
        let componentID = try XCTUnwrap(
            harness.viewModel.addLiveCaptureEvidence(
                to: harness.visitID,
                kind: .mark,
                placement: SpatialPlacement(anchorID: "anchor-1", captureState: .anchored, confidence: .medium),
                scanSessionID: UUID(),
                geometryAnchorID: "anchor-1",
                positionLabel: "Hall"
            )
        )

        let component = try XCTUnwrap(harness.viewModel.component(visitID: harness.visitID, componentID: componentID))
        XCTAssertEqual(component.liveCaptureEvidenceKind, .mark)
        XCTAssertEqual(component.liveCaptureTitle, "Focus")
        XCTAssertNil(component.componentAttributes["componentTypeEvidence"])
        XCTAssertNil(component.componentAttributes["areaEvidence"])
        XCTAssertEqual(component.componentAttributes["geometryAnchorID"], "anchor-1")
        XCTAssertEqual(component.componentAttributes["reviewDecision"], CaptureReviewDecision.unreviewed.rawValue)
        XCTAssertEqual(component.componentAttributes["includedInReviewedHandoff"], "false")
        XCTAssertEqual(component.evidence.count, 1)
        XCTAssertEqual(component.evidence.first?.kind, .textNote)
        XCTAssertEqual(component.evidence.first?.geometryMetadata?.captureMode, .photoOnly)
        XCTAssertEqual(component.evidence.first?.geometryMetadata?.source, .userMarked)

        let visit = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID))
        XCTAssertEqual(visit.evidenceTimelineEntries.first?.evidenceType, "Focus")
        XCTAssertEqual(visit.captureReviewEvidenceGroups.first?.title, "Focus")
    }

    func testFocusModeCreatesHighDetailGeometryEvidence() throws {
        let harness = try makeHarness()
        let devicePosition = SpatialPosition(x: 0.2, y: 1.5, z: -0.1)
        let targetPosition = SpatialPosition(x: 0.8, y: 1.1, z: -0.6)
        let componentID = try XCTUnwrap(
            harness.viewModel.addLiveCaptureEvidence(
                to: harness.visitID,
                kind: .mark,
                placement: SpatialPlacement(anchorID: "focus-anchor", captureState: .anchored, confidence: .high),
                scanSessionID: UUID(),
                geometryAnchorID: "focus-anchor",
                positionLabel: "Boiler cupboard",
                geometryCaptureMode: .focusPointCloud,
                geometryDetailLevel: .local,
                geometrySource: .arkitPointCloud,
                geometryConfidence: .high,
                devicePosition: devicePosition,
                targetPosition: targetPosition
            )
        )

        let component = try XCTUnwrap(harness.viewModel.component(visitID: harness.visitID, componentID: componentID))
        let evidence = try XCTUnwrap(component.evidence.first)
        XCTAssertEqual(component.componentAttributes["geometryCaptureMode"], GeometryCaptureMode.focusPointCloud.rawValue)
        XCTAssertEqual(component.componentAttributes["geometryDetailLevel"], GeometryDetailLevel.local.rawValue)
        XCTAssertEqual(component.componentAttributes["geometrySource"], GeometrySource.arkitPointCloud.rawValue)
        XCTAssertEqual(evidence.geometryMetadata?.captureMode, .focusPointCloud)
        XCTAssertEqual(evidence.geometryMetadata?.detailLevel, .local)
        XCTAssertEqual(evidence.geometryMetadata?.source, .arkitPointCloud)
        XCTAssertEqual(evidence.geometryMetadata?.linkedItemID, componentID)
        XCTAssertEqual(evidence.geometryMetadata?.confidence, .high)
        XCTAssertEqual(evidence.geometryMetadata?.needsReview, true)
        XCTAssertEqual(evidence.geometryMetadata?.devicePosition, devicePosition)
        XCTAssertEqual(evidence.geometryMetadata?.targetPosition, targetPosition)
        XCTAssertEqual(component.componentAttributes["devicePositionX"], String(devicePosition.x))
        XCTAssertEqual(component.componentAttributes["targetPositionZ"], String(targetPosition.z))
    }

    func testRoomPlanCapturePathSavesCompatibleEvidenceMetadata() throws {
        let harness = try makeHarness()
        let componentID = try XCTUnwrap(
            harness.viewModel.addLiveCaptureEvidence(
                to: harness.visitID,
                kind: .photo,
                placement: SpatialPlacement(anchorID: "room-outline-1", captureState: .anchored, confidence: .medium),
                photoData: Data([0xFF, 0xD8]),
                scanSessionID: UUID(),
                geometryAnchorID: "room-outline-1",
                positionLabel: "Room understood",
                geometryCaptureMode: .roomPlan,
                geometryDetailLevel: .room,
                geometrySource: .roomPlan,
                geometryConfidence: .medium
            )
        )

        let visit = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID))
        let component = try XCTUnwrap(visit.components.first { $0.id == componentID })
        let evidence = try XCTUnwrap(component.evidence.first)
        XCTAssertEqual(evidence.geometryMetadata?.captureMode, .roomPlan)
        XCTAssertEqual(evidence.geometryMetadata?.detailLevel, .room)
        XCTAssertEqual(evidence.geometryMetadata?.source, .roomPlan)

        let package = try harness.repository.exportPackage(visits: [visit])
        let exportedEvidence = try XCTUnwrap(package.visits.first?.components.first?.evidence.first)
        XCTAssertEqual(exportedEvidence.geometryMetadata?.captureMode, .roomPlan)
        XCTAssertEqual(exportedEvidence.geometryMetadata?.source, .roomPlan)
    }

    func testTappedObjectSavesEstimatedDimensionsAsReviewablePhotoEvidence() throws {
        let harness = try makeHarness()
        let linkedPhotoID = UUID(uuidString: "00000000-0000-0000-0000-000000000777")!
        let componentID = try XCTUnwrap(
            harness.viewModel.addDetectedObjectMeasurementEvidence(
                to: harness.visitID,
                itemType: .boiler,
                dimensions: EstimatedObjectDimensions(width: 0.72, height: 0.88, depth: 0.34),
                linkedPhotoID: linkedPhotoID,
                confidence: .medium
            )
        )

        let component = try XCTUnwrap(harness.viewModel.component(visitID: harness.visitID, componentID: componentID))
        let evidence = try XCTUnwrap(component.evidence.first)
        XCTAssertEqual(component.name, "Boiler")
        XCTAssertEqual(component.componentAttributes["geometryCaptureMode"], GeometryCaptureMode.roomPlan.rawValue)
        XCTAssertEqual(component.componentAttributes["geometrySource"], GeometrySource.detectedBoundingBox.rawValue)
        XCTAssertEqual(component.componentAttributes["linkedPhotoID"], linkedPhotoID.uuidString)
        XCTAssertEqual(evidence.reviewStatus, .needsReview)
        XCTAssertEqual(evidence.geometryMetadata?.captureMode, .roomPlan)
        XCTAssertEqual(evidence.geometryMetadata?.source, .detectedBoundingBox)
        XCTAssertEqual(evidence.geometryMetadata?.detailLevel, .component)
        XCTAssertEqual(evidence.geometryMetadata?.linkedPhotoID, linkedPhotoID)
        XCTAssertEqual(evidence.geometryMetadata?.itemType, MeasuredObjectType.boiler.rawValue)
        XCTAssertEqual(evidence.geometryMetadata?.estimatedWidth, 0.72)
        XCTAssertEqual(evidence.geometryMetadata?.estimatedHeight, 0.88)
        XCTAssertEqual(evidence.geometryMetadata?.estimatedDepth, 0.34)
        XCTAssertEqual(evidence.geometryMetadata?.needsReview, true)
    }

    func testLivePhotoAndSafetyUseEvidenceActionsWithoutClassification() throws {
        let harness = try makeHarness()
        let photoID = try XCTUnwrap(
            harness.viewModel.addLiveCaptureEvidence(
                to: harness.visitID,
                kind: .photo,
                placement: SpatialPlacement(anchorID: "photo-anchor", captureState: .anchored, confidence: .high),
                photoData: Data([0xFF, 0xD8]),
                scanSessionID: UUID()
            )
        )
        let safetyID = try XCTUnwrap(
            harness.viewModel.addLiveCaptureEvidence(
                to: harness.visitID,
                kind: .safety,
                placement: SpatialPlacement(anchorID: "safety-anchor", captureState: .anchored, confidence: .medium),
                scanSessionID: UUID()
            )
        )

        let photo = try XCTUnwrap(harness.viewModel.component(visitID: harness.visitID, componentID: photoID))
        let safety = try XCTUnwrap(harness.viewModel.component(visitID: harness.visitID, componentID: safetyID))
        XCTAssertEqual(photo.liveCaptureEvidenceKind, .photo)
        XCTAssertEqual(photo.evidence.first?.kind, .photo)
        XCTAssertEqual(safety.liveCaptureEvidenceKind, .safety)
        XCTAssertEqual(safety.evidence.first?.kind, .textNote)
        XCTAssertEqual(safety.reviewStatus, .needsAttention)
        XCTAssertNil(photo.componentAttributes["componentTypeEvidence"])
        XCTAssertNil(safety.componentAttributes["componentTypeEvidence"])

        let timelineTypes = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID)).evidenceTimelineEntries.map(\.evidenceType)
        XCTAssertTrue(timelineTypes.contains("Photo"))
        XCTAssertTrue(timelineTypes.contains("Safety"))
    }

    func testLiveVoiceCreatesTranscriptPlaceholderInSpatialSession() throws {
        let harness = try makeHarness()
        let componentID = try XCTUnwrap(
            harness.viewModel.addLiveCaptureEvidence(
                to: harness.visitID,
                kind: .voice,
                placement: SpatialPlacement(
                    anchorID: "voice-anchor",
                    approximatePosition: SpatialPosition(x: 1.2, y: 0.4, z: -0.8),
                    captureState: .anchored,
                    confidence: .medium
                ),
                scanSessionID: UUID(),
                geometryAnchorID: "voice-anchor",
                positionLabel: "2 surfaces captured"
            )
        )

        let visit = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID))
        let component = try XCTUnwrap(harness.viewModel.component(visitID: harness.visitID, componentID: componentID))
        let evidence = try XCTUnwrap(component.evidence.first)

        XCTAssertEqual(component.liveCaptureEvidenceKind, .voice)
        XCTAssertEqual(component.spatialPlacement.captureState, .anchored)
        XCTAssertEqual(component.spatialPlacement.anchorID, "voice-anchor")
        XCTAssertEqual(evidence.kind, .voiceNote)
        XCTAssertEqual(evidence.reviewStatus, .unreviewed)
        XCTAssertEqual(evidence.transcriptReferences.first?.transcriptID, visit.transcripts.first?.id)
        XCTAssertEqual(visit.recordings.first?.localFileName, evidence.localFileName)
        XCTAssertEqual(visit.transcripts.first?.status, .pending)
        XCTAssertEqual(component.componentAttributes["voiceNoteTranscript"], "Transcript pending.")
    }

    func testPartialSpatialTwinCanBeReviewedMarkedAndExported() throws {
        let harness = try makeHarness()
        let scanSessionID = UUID()
        let photoID = try XCTUnwrap(
            harness.viewModel.addLiveCaptureEvidence(
                to: harness.visitID,
                kind: .photo,
                placement: SpatialPlacement(
                    anchorID: "cupboard-mesh-1",
                    approximatePosition: SpatialPosition(x: 0.4, y: 1.1, z: -0.2),
                    captureState: .anchored,
                    confidence: .high
                ),
                photoData: Data([0xFF, 0xD8, 0xFF]),
                scanSessionID: scanSessionID,
                geometryAnchorID: "cupboard-mesh-1",
                positionLabel: "Boiler cupboard"
            )
        )
        let voiceID = try XCTUnwrap(
            harness.viewModel.addLiveCaptureEvidence(
                to: harness.visitID,
                kind: .voice,
                placement: SpatialPlacement(
                    anchorID: "cupboard-mesh-2",
                    approximatePosition: SpatialPosition(x: 0.6, y: 1.0, z: -0.3),
                    captureState: .anchored,
                    confidence: .medium
                ),
                scanSessionID: scanSessionID,
                geometryAnchorID: "cupboard-mesh-2",
                positionLabel: "Boiler cupboard"
            )
        )
        let markID = try XCTUnwrap(
            harness.viewModel.addLiveCaptureEvidence(
                to: harness.visitID,
                kind: .mark,
                placement: SpatialPlacement(captureState: .approximate, confidence: .low),
                scanSessionID: scanSessionID,
                positionLabel: "Fallback approximate"
            )
        )

        harness.viewModel.setCaptureReviewDecision(.confirmed, componentID: photoID, visitID: harness.visitID)
        harness.viewModel.setCaptureReviewDecision(.changed, componentID: voiceID, visitID: harness.visitID, reviewedLabel: "Boiler voice note")
        harness.viewModel.setCaptureReviewDecision(.ignored, componentID: markID, visitID: harness.visitID)

        let visit = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID))
        XCTAssertTrue(visit.rooms.isEmpty, "A cupboard-only partial twin is valid without a whole-property room pass.")
        XCTAssertEqual(visit.liveCaptureEvidenceComponents.count, 3)
        XCTAssertEqual(visit.reviewedCaptureEvidenceComponents.count, 2)
        XCTAssertEqual(visit.componentMarkers.map(\.title).sorted(), ["Focus", "Photo", "Voice"])
        XCTAssertTrue(visit.componentMarkers.contains { $0.componentID == photoID })
        XCTAssertEqual(try XCTUnwrap(visit.components.first { $0.id == photoID }).spatialPlacement.anchorID, "cupboard-mesh-1")

        let package = try harness.repository.exportPackage(visits: [visit])
        let exportedVisit = try XCTUnwrap(package.visits.first)
        let exportedPhoto = try XCTUnwrap(exportedVisit.components.first { $0.id == photoID })
        let exportedVoice = try XCTUnwrap(exportedVisit.components.first { $0.id == voiceID })
        let exportedFallback = try XCTUnwrap(exportedVisit.components.first { $0.id == markID })

        XCTAssertEqual(exportedPhoto.evidence.first?.kind, .photo)
        XCTAssertNotNil(exportedPhoto.evidence.first?.embeddedData)
        XCTAssertEqual(exportedVoice.evidence.first?.kind, .voiceNote)
        XCTAssertEqual(exportedVoice.evidence.first?.transcriptReferences.first?.transcriptID, exportedVisit.transcripts.first?.id)
        XCTAssertEqual(exportedVoice.componentAttributes["reviewDecision"], CaptureReviewDecision.changed.rawValue)
        XCTAssertEqual(exportedFallback.spatialPlacement.captureState, .approximate)
        XCTAssertEqual(exportedFallback.componentAttributes["includedInReviewedHandoff"], "false")
    }

    func testCaptureReviewStoresWeakSuggestionUntilDecision() throws {
        let harness = try makeHarness()
        let recordingID = try XCTUnwrap(
            harness.viewModel.attachVisitRecordingChunk(
                localFileName: "recording.m4a",
                sequenceNumber: 1,
                to: harness.visitID
            )
        )
        _ = harness.viewModel.attachTranscript(
            sourceRecordingID: recordingID,
            rawTranscript: "This is the boiler in the utility room.",
            chunks: [],
            to: harness.visitID
        )
        let componentID = try XCTUnwrap(
            harness.viewModel.addLiveCaptureEvidence(
                to: harness.visitID,
                kind: .photo,
                placement: SpatialPlacement(anchorID: "anchor-photo", captureState: .anchored, confidence: .high),
                photoData: Data([0xFF, 0xD8]),
                recordingID: recordingID
            )
        )

        harness.viewModel.refreshCaptureReviewSuggestions(for: harness.visitID)
        var component = try XCTUnwrap(harness.viewModel.component(visitID: harness.visitID, componentID: componentID))
        XCTAssertEqual(component.componentAttributes["suggestedLabel"], "Boiler")
        XCTAssertEqual(component.componentAttributes["reviewDecision"], CaptureReviewDecision.unreviewed.rawValue)
        XCTAssertEqual(component.reviewStatus, ReviewStatus.unreviewed)

        harness.viewModel.setCaptureReviewDecision(.confirmed, componentID: componentID, visitID: harness.visitID)
        component = try XCTUnwrap(harness.viewModel.component(visitID: harness.visitID, componentID: componentID))
        XCTAssertEqual(component.componentAttributes["reviewDecision"], CaptureReviewDecision.confirmed.rawValue)
        XCTAssertEqual(component.componentAttributes["reviewedLabel"], "Boiler")
        XCTAssertEqual(component.componentAttributes["includedInReviewedHandoff"], "true")
        XCTAssertEqual(component.reviewStatus, ReviewStatus.confirmed)
    }

    func testChangedIgnoredAndSafetyReviewAffectReviewedPackageReadiness() throws {
        let harness = try makeHarness()
        let markID = try XCTUnwrap(
            harness.viewModel.addLiveCaptureEvidence(to: harness.visitID, kind: .mark, placement: nil)
        )
        let safetyID = try XCTUnwrap(
            harness.viewModel.addLiveCaptureEvidence(to: harness.visitID, kind: .safety, placement: nil)
        )

        var visit = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID))
        XCTAssertTrue(visit.hasBlockingCaptureReviewItems)
        XCTAssertFalse(harness.viewModel.prepareReviewedCapturePackage(for: harness.visitID))

        harness.viewModel.setCaptureReviewDecision(.changed, componentID: markID, visitID: harness.visitID, reviewedLabel: "Valve")
        harness.viewModel.setCaptureReviewDecision(.ignored, componentID: safetyID, visitID: harness.visitID)

        visit = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID))
        XCTAssertFalse(visit.hasBlockingCaptureReviewItems)
        XCTAssertTrue(harness.viewModel.prepareReviewedCapturePackage(for: harness.visitID))

        let mark = try XCTUnwrap(harness.viewModel.component(visitID: harness.visitID, componentID: markID))
        let safety = try XCTUnwrap(harness.viewModel.component(visitID: harness.visitID, componentID: safetyID))
        XCTAssertEqual(mark.componentAttributes["reviewedLabel"], "Valve")
        XCTAssertEqual(mark.componentAttributes["includedInReviewedHandoff"], "true")
        XCTAssertEqual(safety.componentAttributes["reviewDecision"], CaptureReviewDecision.ignored.rawValue)
        XCTAssertEqual(safety.componentAttributes["includedInReviewedHandoff"], "false")
    }

    func testLiveCaptureSourceDoesNotExposeBannedLiveLabels() throws {
        let source = try String(contentsOfFile: liveCaptureSourcePath(), encoding: .utf8)
        let bannedTerms = [
            "\"Audio Marker\"",
            "unknown infrastructure",
            "Marked moment",
            "\"system type\"",
            "\"S-plan\"",
            "\"Y-plan\"",
            "\"combi\"",
            "\"regular\"",
            "\"system boiler\"",
            "\"thermal store\""
        ]

        for term in bannedTerms {
            XCTAssertFalse(source.localizedCaseInsensitiveContains(term), "Live capture source contains banned term: \(term)")
        }

        for required in ["\"Safety hazard\"", "\"Review capture\"", "\"Pause & Review\"", "\"Capture evidence\"", "\"End survey\""] {
            XCTAssertTrue(source.contains(required), "Live capture source should expose \(required)")
        }
        XCTAssertFalse(source.contains("\"CAP.\""), "Primary shutter should be a blank yellow dial")
        XCTAssertFalse(source.contains("LiveMiniTwinMapView"), "Live capture should not render a 2D mini-map panel")
        XCTAssertTrue(source.contains("LiveCaptureSideMenus"), "Hazard and review controls should live in side menus separate from the shutter dock")
        XCTAssertFalse(source.contains("LiveCaptureUtilityRail"), "Live capture should not expose utilities as an always-visible rail")
        XCTAssertFalse(source.contains("Geometry not available yet"), "Live survey should not show unavailable geometry once surfaces are captured")
        XCTAssertFalse(source.contains("Room geometry active"), "Live survey should not claim fake room geometry")
        XCTAssertFalse(source.localizedCaseInsensitiveContains("Detected geometry"), "Normal survey should not expose diagnostic geometry labels")
        XCTAssertFalse(source.localizedCaseInsensitiveContains("surfaces captured"), "Normal survey should not expose surface counts")
        XCTAssertFalse(source.localizedCaseInsensitiveContains("spatial confidence"), "Normal survey should not expose tracking confidence language")
        XCTAssertFalse(source.localizedCaseInsensitiveContains("feature points"), "Normal survey should not expose AR debug language")
        XCTAssertTrue(source.contains("Building room outline"), "Live survey should expose clean room capture progress")
        XCTAssertTrue(source.contains("Room understood"), "Live survey should expose clean room capture completion")
        let sessionSource = try sourceText(relativePath: "DaedalusScan/Features/Visits/SpatialCaptureSession.swift")
        XCTAssertTrue(sessionSource.contains("Needs another angle"), "Live survey state should retain plain fallback guidance")
        XCTAssertTrue(source.contains("\"End survey\""), "Live survey should expose an explicit route out")
        XCTAssertFalse(source.contains("Room understood\"), systemImage"), "Live survey should avoid duplicate Room understood status rows")

        let lifecycleSource = try sourceText(relativePath: "DaedalusScan/Features/Visits/TwinLifecycleViews.swift")
        XCTAssertTrue(lifecycleSource.contains("\"Resume Survey\""), "Review should expose a Resume Survey action")
    }

    func testLiveCaptureSourceDoesNotShowSuggestionConfirmationCardDuringSurvey() throws {
        let source = try sourceText(relativePath: "DaedalusScan/Features/Visits/LiveCaptureView.swift")

        XCTAssertFalse(source.contains("LiveCaptureConfirmationView"))
        XCTAssertFalse(source.contains("\"Captured Suggestion\""))
        XCTAssertFalse(source.contains("\"What was observed:\""))
        XCTAssertFalse(source.contains("\"Daedalus thinks this is:\""))
        XCTAssertFalse(source.contains("\"Needs Confirmation\""))
        XCTAssertFalse(source.contains("\"Review Later\""))
        XCTAssertFalse(source.contains("reviewLiveCaptureLater"))
        XCTAssertFalse(source.contains("@State private var confirmationState"))
        XCTAssertFalse(source.contains("confirmationState.recentEvents"))
        XCTAssertFalse(source.contains("confirmationState.record"), "Live capture should not open a confirmation workflow while scanning")
    }

    func testLiveCaptureClearsTransientSessionStateWithoutBlockingOverlay() throws {
        let source = try sourceText(relativePath: "DaedalusScan/Features/Visits/LiveCaptureView.swift")
        let leaveSource = try sourceBlock(
            named: "private func leaveSurvey",
            endingBefore: "private func resumeSurvey",
            in: source
        )
        let teardownSource = try sourceBlock(
            named: "private func teardownTransientCaptureUI",
            endingBefore: "private func syncPlacementStateForSession",
            in: source
        )

        XCTAssertFalse(source.contains("private func confirmLiveCapture"))
        XCTAssertFalse(source.contains("private func markLiveCaptureUnresolved"))
        XCTAssertFalse(source.contains("private func reviewLiveCaptureLater"))
        XCTAssertFalse(source.contains("dismissLiveCaptureConfirmation"))
        XCTAssertTrue(leaveSource.contains("teardownTransientCaptureUI()"))
        XCTAssertTrue(source.contains(".onAppear {\n                resetTransientCaptureUI()"), "Re-entering live capture should start without zombie overlay state")
        XCTAssertTrue(source.contains(".onDisappear {\n                teardownTransientCaptureUI()"), "Leaving live capture should clear transient overlay state")
        XCTAssertFalse(teardownSource.contains("confirmationState"), "Live capture should not own review confirmation state")
        XCTAssertTrue(teardownSource.contains("didRequestSpatialStart = false"))
        XCTAssertTrue(teardownSource.contains("spatialSession.status = .notStarted"))
        XCTAssertTrue(teardownSource.contains("capturedEvidenceComponentID = nil"))
        XCTAssertTrue(teardownSource.contains("scanProgress = .empty"))
        XCTAssertTrue(teardownSource.contains("spatialAim = .empty"))
        XCTAssertTrue(teardownSource.contains("livePlacementState = .unavailable"))
        XCTAssertTrue(teardownSource.contains("captureState = .idle"))
        XCTAssertTrue(source.contains("guard didRequestSpatialStart else { return }\n            startSpatialSession()"), "Deferred capture startup should not restart after teardown")
    }

    func testUserFacingCaptureLanguageUsesPropertyRootTerms() throws {
        let source = try sourceText(relativePath: "DaedalusScan/Features/Visits/LiveCaptureView.swift") +
            sourceText(relativePath: "DaedalusScan/Features/Visits/VisitDetailView.swift") +
            sourceText(relativePath: "DaedalusScan/Features/Visits/TwinLifecycleViews.swift") +
            sourceText(relativePath: "DaedalusScan/Features/Visits/SurveySectionCaptureView.swift") +
            sourceText(relativePath: "DaedalusScan/Features/Visits/AttachEvidenceSheet.swift") +
            sourceText(relativePath: "DaedalusScan/Features/Visits/CaptureSessionState.swift")

        XCTAssertTrue(source.contains("\"Property not found\""))
        XCTAssertTrue(source.contains("\"Working Twin Context\""))
        XCTAssertTrue(source.contains("\"Review Capture\""))
        XCTAssertFalse(source.contains("\"Property Twin"), "User-facing root labels should use Property or Working Twin, not Property Twin")
    }

    func testLiveCaptureControlsRespectSafeAreaAndNarrowWidths() throws {
        let source = try sourceText(relativePath: "DaedalusScan/Features/Visits/LiveCaptureView.swift")
        let surfaceSource = try sourceBlock(
            named: "private func liveCaptureSurface",
            endingBefore: "private var currentPlacementMetadata",
            in: source
        )
        let cameraSource = try sourceBlock(
            named: "private func cameraFirstCapture",
            endingBefore: "private func liveCaptureSurface",
            in: source
        )
        let statusBarSource = try sourceBlock(
            named: "private struct LiveCaptureStatusBar",
            endingBefore: "private struct LiveSurveyCoverageOverlay",
            in: source
        )
        let spatialSource = try sourceText(relativePath: "DaedalusScan/Platform/LiveSpatialCaptureView.swift")

        XCTAssertTrue(surfaceSource.contains(".safeAreaInset(edge: .top"), "Top capture controls should stay below the Dynamic Island/status area")
        XCTAssertTrue(surfaceSource.contains(".safeAreaInset(edge: .bottom"), "Shutter controls should stay above the home indicator")
        XCTAssertTrue(surfaceSource.contains(".frame(maxWidth: 320)"), "Top capture banner should be capped so it cannot span off screen")
        XCTAssertTrue(surfaceSource.contains("LiveSpatialCaptureView("))
        XCTAssertTrue(surfaceSource.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)"), "Camera host should explicitly fill the live capture surface")
        XCTAssertTrue(surfaceSource.contains(".ignoresSafeArea()"), "Camera and scrim should still fill the whole screen")
        XCTAssertTrue(surfaceSource.contains(".background(Color.black)"), "Live capture should own its background instead of exposing parent grey bars")
        XCTAssertFalse(surfaceSource.contains(".aspectRatio("), "Live capture surface must not be constrained by a hardcoded narrow aspect ratio")
        XCTAssertFalse(cameraSource.contains(".ignoresSafeArea()"), "The whole control surface must not ignore safe areas")
        XCTAssertTrue(statusBarSource.contains(".minimumScaleFactor(0.65)"), "Property references should scale instead of pushing controls off screen")
        XCTAssertTrue(statusBarSource.contains(".minimumScaleFactor(0.58)"), "Placement labels should shrink before widening the banner")
        XCTAssertTrue(spatialSource.contains("container.backgroundColor = .black"), "UIKit camera container should not reveal grey parent chrome")
        XCTAssertTrue(spatialSource.contains("setContentCompressionResistancePriority(.defaultLow"), "UIKit camera container should expand inside SwiftUI instead of dictating a narrow size")
        XCTAssertTrue(spatialSource.contains("addRoomCaptureView"))
        XCTAssertTrue(spatialSource.contains("child.leadingAnchor.constraint(equalTo: container.leadingAnchor)"), "RoomPlan preview should fill horizontally instead of letterboxing against safe-area gutters")
        XCTAssertTrue(spatialSource.contains("child.trailingAnchor.constraint(equalTo: container.trailingAnchor)"), "RoomPlan preview should fill horizontally instead of letterboxing against safe-area gutters")
        XCTAssertFalse(spatialSource.contains("container.safeAreaLayoutGuide.leadingAnchor, constant: 12"))
        XCTAssertFalse(spatialSource.contains("container.safeAreaLayoutGuide.trailingAnchor, constant: -12"))
    }

    func testPropertyDashboardLayoutIsNotDrivenByLiveCaptureViewportState() throws {
        let lifecycleSource = try sourceText(relativePath: "DaedalusScan/Features/Visits/TwinLifecycleViews.swift")
        let homeSource = try sourceBlock(
            named: "struct PropertyTwinHomeView",
            endingBefore: "struct StageModeView",
            in: lifecycleSource
        )
        let captureSource = try sourceText(relativePath: "DaedalusScan/Features/Visits/LiveCaptureView.swift")

        XCTAssertTrue(homeSource.contains("List {"), "Property dashboard should own its own list layout")
        XCTAssertTrue(homeSource.contains("LiveCaptureView(viewModel: viewModel, visitID: visitID)"))
        XCTAssertFalse(homeSource.contains("ignoresSafeArea"), "Live capture viewport choices must not be applied to the property dashboard")
        XCTAssertFalse(homeSource.contains("safeAreaInset"), "Live capture control insets must not be applied to the property dashboard")
        XCTAssertTrue(captureSource.contains("teardownTransientCaptureUI()"), "Live capture should reset transient viewport state before returning to the dashboard")
    }

    func testCaptureSourceDoesNotIntroduceBannedBoundaryBehaviours() throws {
        let source = try sourceText(relativePath: "DaedalusScan/ViewModels/VisitListViewModel.swift") +
            sourceText(relativePath: "DaedalusScan/Features/Visits/LiveCaptureEvidence.swift") +
            sourceText(relativePath: "DaedalusScan/Features/Visits/LiveCaptureView.swift")
        let bannedTerms = [
            "recommendation",
            "recommended",
            "quote",
            "pricing",
            "customer advice",
            "heat loss",
            "crm",
            "scheduling"
        ]

        for term in bannedTerms {
            XCTAssertFalse(source.localizedCaseInsensitiveContains(term), "Capture code contains banned boundary behaviour: \(term)")
        }
    }

    func testCreateVisitReferenceDoesNotForceCapsLock() throws {
        let source = try sourceText(relativePath: "DaedalusScan/Features/Visits/CreateVisitView.swift")
        XCTAssertTrue(source.contains(".textInputAutocapitalization(.never)"), "Visit reference input should preserve user casing")
        XCTAssertFalse(source.contains("TextField(\"Property reference (required)\", text: $reference)\n                        .textInputAutocapitalization(.characters)"))
    }

    func testPropertiesScreenUsesDaedalusLogoAndReadableVisitRows() throws {
        let source = try sourceText(relativePath: "DaedalusScan/Features/Visits/VisitListView.swift")
        let brandHeader = try sourceBlock(
            named: "private struct AppBrandHeader",
            endingBefore: "private struct VisitMetadataChip",
            in: source
        )
        let visitRow = try sourceBlock(
            named: "private func visitRow",
            endingBefore: "private func reviewNeedsCount",
            in: source
        )

        XCTAssertTrue(brandHeader.contains("Image(\"DaedalusLogo\")"))
        XCTAssertFalse(brandHeader.contains("Text(\"D\")"), "Properties screen should not draw the old blue D placeholder")
        XCTAssertTrue(visitRow.contains("VisitMetadataChip"))
        XCTAssertFalse(visitRow.contains("Label(\"System · House · Home\""), "Visit rows should not squeeze long metadata into vertical strips")
        XCTAssertTrue(source.contains(".lineLimit(1)"))
        XCTAssertTrue(source.contains(".minimumScaleFactor(0.8)"))
    }

    func testLiveCaptureUtilitiesUseSwipeInSideMenusNotButtonRail() throws {
        let source = try sourceText(relativePath: "DaedalusScan/Features/Visits/LiveCaptureView.swift")

        XCTAssertFalse(source.contains("LiveCaptureUtilityRail"), "Live capture utilities should not be an always-visible button rail")
        XCTAssertTrue(source.contains("private struct LiveCaptureSideMenus"), "Live capture should render swipe-in side menus")
        XCTAssertTrue(source.contains("@State private var activeSideDrawer"), "Live capture should track which side drawer is open")
        XCTAssertTrue(source.contains("DragGesture(minimumDistance:"), "Side menus should be opened by edge swipes")
        XCTAssertTrue(source.contains("edgeSwipeZone(side: .survey)"), "Survey menu should have a left edge swipe zone")
        XCTAssertTrue(source.contains("edgeSwipeZone(side: .markers)"), "Marker menu should have a right edge swipe zone")
        XCTAssertTrue(source.contains("LiveCaptureMenuItem(title: \"Next Room\""))
        XCTAssertTrue(source.contains("LiveCaptureMenuItem(title: \"Focused Scan\""))
        XCTAssertTrue(source.contains("LiveCaptureMenuItem(title: \"Gas\""))
        XCTAssertTrue(source.contains("LiveCaptureMenuItem(title: \"Water Pressure Test\""))
        XCTAssertTrue(source.contains("LiveCaptureMenuItem(title: \"Socket Check\""))
        XCTAssertTrue(source.contains("LiveCaptureMenuItem(title: \"Place Ruler\""))
        XCTAssertTrue(source.contains("LiveCaptureMenuItem(title: \"Safety Issue\""))
    }

    func testLiveSpatialCaptureDoesNotEagerlyCreateHeavyRenderers() throws {
        let source = try sourceText(relativePath: "DaedalusScan/Platform/LiveSpatialCaptureView.swift")
        let makeUIViewStart = try XCTUnwrap(source.range(of: "func makeUIView(context: Context) -> UIView"))
        let makeUIViewEnd = try XCTUnwrap(source[makeUIViewStart.lowerBound...].range(of: "func updateUIView"))
        let makeUIViewSource = String(source[makeUIViewStart.lowerBound..<makeUIViewEnd.lowerBound])

        XCTAssertFalse(makeUIViewSource.contains("ARSCNView("), "Startup should not eagerly create ARSCNView before scanning/focus")
        XCTAssertFalse(makeUIViewSource.contains("RoomCaptureView("), "Startup should not eagerly create RoomCaptureView before scanning")
        XCTAssertTrue(source.contains("ensureSceneView()"), "AR fallback/focus renderer should be lazy")
        XCTAssertTrue(source.contains("ensureRoomCaptureView()"), "RoomPlan renderer should be lazy")
    }

    func testLiveCaptureSourceUsesCenterRaycastWithoutMiniTwinPanel() throws {
        let captureSource = try sourceText(relativePath: "DaedalusScan/Features/Visits/LiveCaptureView.swift")
        let controlBarSource = try sourceBlock(
            named: "private struct LiveCaptureControlBar",
            endingBefore: "private struct LiveCaptureMiniTimeline",
            in: captureSource
        )
        XCTAssertFalse(captureSource.contains("LiveMiniTwinMapView"), "Live capture should not render a 2D Mini Twin Map overlay")
        XCTAssertFalse(captureSource.contains("EvidenceMapPin"), "Live capture should not maintain 2D map pins")
        XCTAssertFalse(controlBarSource.contains("\"Photo\""), "Bottom dock should not duplicate the shutter with a Photo mode")
        XCTAssertFalse(controlBarSource.contains("\"Voice Note\""), "Bottom dock should not expose manual voice mode during continuous recording")
        XCTAssertFalse(controlBarSource.contains("\"Mark Item\""), "Bottom dock should not expose manual pin mode")
        XCTAssertFalse(controlBarSource.contains("\"Focus\""), "Bottom dock should not expose focus as a mode toggle")
        XCTAssertFalse(controlBarSource.contains("\"Safety\""), "Hazard flag should live outside the shutter dock")
        XCTAssertFalse(controlBarSource.contains("\"Review\""), "Review should live outside the shutter dock")
        XCTAssertFalse(controlBarSource.contains("liveButton("), "Bottom dock should only render the primary shutter")
        XCTAssertTrue(controlBarSource.contains("Button(action: onCapture)"), "Bottom dock should bind the primary shutter directly")
        XCTAssertFalse(captureSource.contains("CaptureConfirmationEvent"), "Live capture should not render review suggestion events")
        XCTAssertFalse(captureSource.contains("areaSections"), "Live capture should not maintain a suggestion stack")
        XCTAssertFalse(captureSource.contains("shortStatus(for:"), "Review statuses belong in the review workspace")
        XCTAssertTrue(captureSource.contains("spatialAim.targetPosition"), "Evidence should use the current target position")
        XCTAssertTrue(captureSource.contains("spatialAim.devicePosition"), "Evidence should use the current device position")
        XCTAssertFalse(captureSource.contains("\"CAP.\""), "The primary shutter control should not contain text")
        XCTAssertFalse(captureSource.contains("design: .monospaced"), "Blank shutter should not need text styling")
        XCTAssertTrue(captureSource.contains("private func capAction()"))
        XCTAssertTrue(captureSource.contains("snapshotRequestID = UUID()"), "Shutter should request a live camera snapshot")
        XCTAssertTrue(captureSource.contains("private func saveCapturedFrame(_ data: Data)"))
        XCTAssertTrue(captureSource.contains("createLiveEvidence(.photo, photoData: data)"), "Photo evidence should be saved with captured image bytes")
        XCTAssertFalse(captureSource.contains("createLiveEvidence(.photo, photoData: nil)"), "Shutter must not create placeholder photo evidence")

        let rendererSource = try sourceText(relativePath: "DaedalusScan/Platform/LiveSpatialCaptureView.swift")
        XCTAssertTrue(rendererSource.contains("captureSnapshotIfNeeded"), "AR view should service shutter snapshot requests")
        XCTAssertTrue(rendererSource.contains("captureVisibleFrameData"), "AR view should capture the visible camera frame")
        XCTAssertTrue(rendererSource.contains("currentFrame"), "Live snapshots should use the active AR session frame")
        XCTAssertTrue(rendererSource.contains("capturedImage"), "Live snapshots should read the AR camera image buffer")
        XCTAssertTrue(rendererSource.contains("CIImage(cvPixelBuffer:"), "Live snapshots should convert the camera pixel buffer")
        XCTAssertTrue(rendererSource.contains("jpegData(compressionQuality:"), "Live snapshots should be encoded before evidence creation")
        XCTAssertFalse(rendererSource.contains("drawHierarchy"), "Live shutter must not screenshot RoomPlan or AR UIKit hierarchies")
        XCTAssertFalse(rendererSource.contains("UIGraphicsImageRenderer"), "Live shutter should avoid UIKit hierarchy rendering for AR views")
        XCTAssertTrue(rendererSource.contains("raycastQuery(from:"), "AR view should query the screen-centre raycast target")
        XCTAssertTrue(rendererSource.contains("session.raycast(query)"), "AR view should raycast against the active session")
        XCTAssertTrue(rendererSource.contains("guard let frame = sceneView.session.currentFrame else"), "Raycaster should exit when no frame is available")
        XCTAssertTrue(rendererSource.contains("Task { @MainActor in"), "AR session mutations should be scheduled on the main actor")
        XCTAssertTrue(rendererSource.contains("devicePosition"), "AR view should publish where the surveyor stood")
        XCTAssertTrue(rendererSource.contains("targetPosition"), "AR view should publish where the camera points")
        XCTAssertTrue(rendererSource.contains("ARMeshAnchor"), "Focus capture should still handle mesh anchor updates")
    }

    func testCaptureStateMachineSeparatesRoomAndFocusModes() throws {
        let sessionSource = try sourceText(relativePath: "DaedalusScan/Features/Visits/SpatialCaptureSession.swift")
        for state in ["idle", "roomScanning", "roomUnderstood", "focusPreparing", "focusCapturing", "focusCaptured", "focusEnding", "error"] {
            XCTAssertTrue(sessionSource.contains("case \(state)"), "Capture state should include \(state)")
        }

        let captureSource = try sourceText(relativePath: "DaedalusScan/Features/Visits/LiveCaptureView.swift")
        XCTAssertTrue(captureSource.contains("captureState = .focusPreparing"))
        XCTAssertTrue(captureSource.contains("captureState = .focusEnding"))
        XCTAssertTrue(captureSource.contains("captureState = .roomScanning"))
        XCTAssertFalse(captureSource.contains("@State private var isFocusModeActive"), "Focus mode should derive from explicit capture state")

        let rendererSource = try sourceText(relativePath: "DaedalusScan/Platform/LiveSpatialCaptureView.swift")
        XCTAssertTrue(rendererSource.contains("stopSessions()"), "Mode changes should stop the previous capture path")
        XCTAssertTrue(rendererSource.contains("clearTransientOverlays()"), "Mode changes should clear stale overlays")
        XCTAssertTrue(rendererSource.contains("roomCaptureView?.captureSession.stop()"), "Focus mode should stop RoomPlan")
        XCTAssertTrue(rendererSource.contains("sceneView?.session.pause()"), "Room mode should pause ARKit focus capture")
        XCTAssertTrue(rendererSource.contains("maximumCount: 1_500"), "Focus point rendering should be capped")
    }

    func testPhotoWithSpatialMetadataAppearsAsOneReviewEvidenceItem() throws {
        let harness = try makeHarness()
        let componentID = try XCTUnwrap(
            harness.viewModel.addLiveCaptureEvidence(
                to: harness.visitID,
                kind: .photo,
                placement: SpatialPlacement(anchorID: "photo-anchor", captureState: .anchored, confidence: .high),
                photoData: Data([0xFF, 0xD8, 0xFF]),
                scanSessionID: UUID(),
                geometryAnchorID: "photo-anchor",
                positionLabel: "Utility",
                geometryCaptureMode: .roomPlan,
                geometryDetailLevel: .room,
                geometrySource: .roomPlan,
                geometryConfidence: .high
            )
        )

        let visit = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID))
        let cards = visit.captureReviewCards.filter { $0.componentID == componentID }
        XCTAssertEqual(cards.count, 1)
        let card = try XCTUnwrap(cards.first)
        XCTAssertEqual(card.evidenceType, "Photo")
        XCTAssertEqual(card.areaName, "Utility")
        XCTAssertNotNil(card.photoFileName)
        XCTAssertTrue(card.spatialMetadata.contains("RoomPlan"))
        XCTAssertFalse(visit.captureReviewWorkspaceSummary.observations.contains { $0.detail == card.objectName && $0.title == "Text Note" })
    }

    func testThumbnailRemainsAvailableAfterReviewReloadAndDecisions() throws {
        let harness = try makeHarness()
        let componentID = try XCTUnwrap(
            harness.viewModel.addLiveCaptureEvidence(
                to: harness.visitID,
                kind: .photo,
                placement: SpatialPlacement(anchorID: "persist-anchor", captureState: .anchored, confidence: .medium),
                photoData: Data([0xFF, 0xD8, 0xFF]),
                scanSessionID: UUID()
            )
        )

        var visit = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID))
        var card = try XCTUnwrap(visit.captureReviewCards.first { $0.componentID == componentID })
        var fileName = try XCTUnwrap(card.photoFileName)
        XCTAssertNotNil(harness.viewModel.evidenceFileURL(localFileName: fileName))

        let reloadedViewModel = VisitListViewModel(repository: harness.repository)
        visit = try XCTUnwrap(reloadedViewModel.visit(id: harness.visitID))
        card = try XCTUnwrap(visit.captureReviewCards.first { $0.componentID == componentID })
        fileName = try XCTUnwrap(card.photoFileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(reloadedViewModel.evidenceFileURL(localFileName: fileName)).path))

        reloadedViewModel.setCaptureReviewDecision(.confirmed, componentID: componentID, visitID: harness.visitID)
        visit = try XCTUnwrap(reloadedViewModel.visit(id: harness.visitID))
        card = try XCTUnwrap(visit.captureReviewCards.first { $0.componentID == componentID })
        fileName = try XCTUnwrap(card.photoFileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(reloadedViewModel.evidenceFileURL(localFileName: fileName)).path))
    }

    func testThumbnailExpansionRouteStateExists() throws {
        let source = try sourceText(relativePath: "DaedalusScan/Features/Visits/CaptureReviewWorkspace.swift")
        XCTAssertTrue(source.contains("@State private var activeSheet: CaptureReviewSheet?"))
        XCTAssertTrue(source.contains(".sheet(item: $activeSheet)"))
        XCTAssertTrue(source.contains("case expandedPhoto(ExpandedEvidencePhoto)"))
        XCTAssertTrue(source.contains("ExpandedEvidencePhotoView"))
        XCTAssertTrue(source.contains("activeSheet = .expandedPhoto"))
    }

    func testGeometryReviewSectionRendersWhenGeometryMetadataExists() throws {
        let harness = try makeHarness()
        _ = try XCTUnwrap(
            harness.viewModel.addLiveCaptureEvidence(
                to: harness.visitID,
                kind: .photo,
                placement: SpatialPlacement(anchorID: "room-plan-anchor", captureState: .anchored, confidence: .high),
                photoData: Data([0xFF, 0xD8]),
                scanSessionID: UUID(),
                geometryCaptureMode: .roomPlan,
                geometryDetailLevel: .room,
                geometrySource: .roomPlan,
                geometryConfidence: .high
            )
        )

        let summary = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID)).captureGeometryReviewSummary
        XCTAssertTrue(summary.hasGeometry)
        XCTAssertEqual(summary.spatialEvidenceCount, 1)
        XCTAssertEqual(summary.roomPlanCount, 1)
        XCTAssertEqual(summary.confidence, "High")

        let source = try sourceText(relativePath: "DaedalusScan/Features/Visits/CaptureReviewWorkspace.swift")
        XCTAssertTrue(source.contains("Section(\"Geometry Review\")"))
        XCTAssertTrue(source.contains("GeometryReviewSummaryView"))
    }

    func testReviewCardsDoNotUseRawUUIDFilenameAsPrimaryTitle() throws {
        let harness = try makeHarness()
        let componentID = try XCTUnwrap(
            harness.viewModel.addLiveCaptureEvidence(
                to: harness.visitID,
                kind: .photo,
                placement: SpatialPlacement(anchorID: "title-anchor", captureState: .anchored, confidence: .medium),
                photoData: Data([0xFF, 0xD8]),
                scanSessionID: UUID()
            )
        )

        let card = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID)?.captureReviewCards.first { $0.componentID == componentID })
        XCTAssertFalse(card.objectName.contains(".jpg"))
        XCTAssertNil(UUID(uuidString: card.objectName))
        XCTAssertFalse(card.suggestedLabel.contains(".jpg"))
    }

    func testReviewButtonsUseNonWrappingActionLabels() throws {
        let source = try sourceText(relativePath: "DaedalusScan/Features/Visits/CaptureReviewWorkspace.swift")
        XCTAssertTrue(source.contains("ReviewActionButton"))
        XCTAssertTrue(source.contains(".lineLimit(1)"))
        XCTAssertTrue(source.contains(".minimumScaleFactor(0.72)"))
        XCTAssertFalse(source.contains("Button(\"Mark Unresolved\""))
        XCTAssertFalse(source.contains("ReviewActionButton(title: \"Mark Unresolved\""))
        XCTAssertFalse(source.contains("ReviewActionButton(title: \"Needs attention\""))
    }

    func testLiveSideControlsUseExistingDomainPaths() throws {
        let harness = try makeHarness()
        let gasID = try XCTUnwrap(harness.viewModel.addLiveCaptureEvidence(to: harness.visitID, kind: .gas, placement: nil))
        let waterID = try XCTUnwrap(harness.viewModel.addLiveCaptureEvidence(to: harness.visitID, kind: .water, placement: nil))
        let electricalID = try XCTUnwrap(harness.viewModel.addLiveCaptureEvidence(to: harness.visitID, kind: .electrical, placement: nil))
        let measurementID = try XCTUnwrap(harness.viewModel.addLiveCaptureEvidence(to: harness.visitID, kind: .measurement, placement: nil))

        let visit = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID))
        let specialObjects = visit.areaObjectGroups.flatMap(\.specialObjects)
        XCTAssertTrue(specialObjects.contains { $0.linkedComponentID == gasID && $0.specialObject == .gasEntry })
        XCTAssertTrue(specialObjects.contains { $0.linkedComponentID == waterID && $0.specialObject == .waterEntry })
        XCTAssertTrue(specialObjects.contains { $0.linkedComponentID == electricalID && $0.specialObject == .electricIntake })
        XCTAssertEqual(try XCTUnwrap(visit.components.first { $0.id == measurementID }).liveCaptureEvidenceKind, .measurement)

        let source = try sourceText(relativePath: "DaedalusScan/Features/Visits/LiveCaptureView.swift")
        XCTAssertTrue(source.contains("onNextRoom"))
        XCTAssertTrue(source.contains("onFocus"))
        XCTAssertTrue(source.contains("onGas"))
        XCTAssertTrue(source.contains("onWater"))
        XCTAssertTrue(source.contains("onElectrical"))
        XCTAssertTrue(source.contains("onMeasurement"))
        XCTAssertTrue(source.contains("WaterSupplyTestSheet(viewModel: viewModel, visitID: visitID)"), "Water side menu should enter pressure/flow test results")
        XCTAssertTrue(source.contains("activeCaptureSheet = .waterPressureTest"))
        XCTAssertTrue(source.contains("private func placeGeometryRuler()"))
        XCTAssertTrue(source.contains("geometryDetailLevel: .component"))
        XCTAssertTrue(source.contains("geometrySource: .userMarked"))
        XCTAssertTrue(source.contains("Electrical socket evidence"), "Electrical side menu should stay on the existing evidence path until a socket model exists")
        XCTAssertTrue(source.contains("Focused scan will end the room scan"), "Focused scan should warn before switching away from room scan")
        XCTAssertFalse(source.contains("confirmationState"))
        XCTAssertFalse(source.contains("LiveCaptureConfirmationState"))
    }

    func testReviewUsesRoomStitchingLanguage() throws {
        let source = try sourceText(relativePath: "DaedalusScan/Features/Visits/CaptureReviewWorkspace.swift")
        XCTAssertTrue(source.contains("Stitch With..."))
        XCTAssertFalse(source.contains("Merge With..."))
    }

    func testCaptureSourceRejectsAIAndVisionHooks() throws {
        let source = try sourceText(relativePath: "DaedalusScan/ViewModels/VisitListViewModel.swift") +
            sourceText(relativePath: "DaedalusScan/Features/Visits/LiveCaptureEvidence.swift") +
            sourceText(relativePath: "DaedalusScan/Features/Visits/LiveCaptureView.swift") +
            sourceText(relativePath: "DaedalusScan/Features/Visits/CaptureReviewWorkspace.swift")
        for bannedTerm in [
            "machineVision",
            "VisionSuggestionCandidate",
            "LiveCaptureConfirmationState",
            "CaptureConfirmationEvent",
            "Needs Confirmation",
            "Review Later"
        ] {
            XCTAssertFalse(source.contains(bannedTerm), "Capture code contains banned hook: \(bannedTerm)")
        }
    }

    private struct Harness {
        let viewModel: VisitListViewModel
        let repository: VisitRepository
        let visitID: UUID
    }

    private func makeHarness() throws -> Harness {
        let storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaedalusLiveCapture-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: storageDirectory)
        }
        let repository = VisitRepository(storageDirectory: storageDirectory)
        let viewModel = VisitListViewModel(repository: repository)
        let visitID = try XCTUnwrap(viewModel.createVisit(reference: "Live Visit"))
        return Harness(viewModel: viewModel, repository: repository, visitID: visitID)
    }

    private func liveCaptureSourcePath() -> String {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        return url
            .appendingPathComponent("DaedalusScan")
            .appendingPathComponent("Features")
            .appendingPathComponent("Visits")
            .appendingPathComponent("LiveCaptureView.swift")
            .path
    }

    private func sourceText(relativePath: String) throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        return try String(contentsOf: url.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func sourceBlock(named startMarker: String, endingBefore endMarker: String, in source: String) throws -> String {
        let start = try XCTUnwrap(source.range(of: startMarker))
        let end = try XCTUnwrap(source[start.lowerBound...].range(of: endMarker))
        return String(source[start.lowerBound..<end.lowerBound])
    }
}
