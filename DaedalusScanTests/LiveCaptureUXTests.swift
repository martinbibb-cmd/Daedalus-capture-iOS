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

        let visit = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID))
        XCTAssertEqual(visit.evidenceTimelineEntries.first?.evidenceType, "Focus")
        XCTAssertEqual(visit.captureReviewEvidenceGroups.first?.title, "Focus")
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
            "\"CAP\"",
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

        for required in ["\"Snapshot\"", "\"Note\"", "\"Focus\"", "\"Stop\"", "\"Safety\"", "\"Review\"", "\"Pause & Review\""] {
            XCTAssertTrue(source.contains(required), "Live capture source should expose \(required)")
        }
        XCTAssertFalse(source.contains("Geometry not available yet"), "Live survey should not show unavailable geometry once surfaces are captured")
        XCTAssertTrue(source.contains("Room geometry active"), "Live survey should expose room mapping progress")

        let lifecycleSource = try sourceText(relativePath: "DaedalusScan/Features/Visits/TwinLifecycleViews.swift")
        XCTAssertTrue(lifecycleSource.contains("\"Resume Survey\""), "Review should expose a Resume Survey action")
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
}
