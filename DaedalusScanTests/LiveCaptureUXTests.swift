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
        XCTAssertNil(photo.componentAttributes["componentTypeEvidence"])
        XCTAssertNil(safety.componentAttributes["componentTypeEvidence"])

        let timelineTypes = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID)).evidenceTimelineEntries.map(\.evidenceType)
        XCTAssertTrue(timelineTypes.contains("Photo"))
        XCTAssertTrue(timelineTypes.contains("Safety"))
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
