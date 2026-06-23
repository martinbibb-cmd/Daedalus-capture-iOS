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
        XCTAssertTrue(source.contains("LiveCaptureUtilityRail"), "Hazard and review controls should be separate from the shutter dock")
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

    func testLiveCaptureSourceShowsSuggestionConfirmationCardAndReviewLink() throws {
        let source = try sourceText(relativePath: "DaedalusScan/Features/Visits/LiveCaptureView.swift")

        XCTAssertTrue(source.contains("\"Captured Suggestion\""))
        XCTAssertTrue(source.contains("\"What was observed:\""))
        XCTAssertTrue(source.contains("\"Daedalus thinks this is:\""))
        XCTAssertTrue(source.contains("\"Area:\""))
        XCTAssertTrue(source.contains("\"Status:\""))
        XCTAssertTrue(source.contains("\"Needs Confirmation\""))
        XCTAssertTrue(source.contains("\"Confirm\""))
        XCTAssertTrue(source.contains("\"Mark Unresolved\""))
        XCTAssertTrue(source.contains("\"Review Later\""))
        XCTAssertTrue(source.contains("confirmationState.recentEvents"))
        XCTAssertTrue(source.contains("reviewLiveCaptureLater"))
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
            endingBefore: "private struct LiveCaptureConfirmationView",
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
