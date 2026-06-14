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
        XCTAssertEqual(component.liveCaptureTitle, "Mark")
        XCTAssertNil(component.componentAttributes["componentTypeEvidence"])
        XCTAssertNil(component.componentAttributes["areaEvidence"])
        XCTAssertEqual(component.componentAttributes["geometryAnchorID"], "anchor-1")
        XCTAssertEqual(component.componentAttributes["reviewDecision"], CaptureReviewDecision.unreviewed.rawValue)
        XCTAssertEqual(component.componentAttributes["includedInReviewedHandoff"], "false")
        XCTAssertEqual(component.evidence.count, 1)
        XCTAssertEqual(component.evidence.first?.kind, .textNote)

        let visit = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID))
        XCTAssertEqual(visit.evidenceTimelineEntries.first?.evidenceType, "Mark")
        XCTAssertEqual(visit.captureReviewEvidenceGroups.first?.title, "Mark")
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

        for required in ["\"Photo\"", "\"Mark\"", "\"Safety\"", "\"Finish\""] {
            XCTAssertTrue(source.contains(required), "Live capture source should expose \(required)")
        }
    }

    private struct Harness {
        let viewModel: VisitListViewModel
        let visitID: UUID
    }

    private func makeHarness() throws -> Harness {
        let storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaedalusLiveCapture-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: storageDirectory)
        }
        let viewModel = VisitListViewModel(repository: VisitRepository(storageDirectory: storageDirectory))
        let visitID = try XCTUnwrap(viewModel.createVisit(reference: "Live Visit"))
        return Harness(viewModel: viewModel, visitID: visitID)
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
}
