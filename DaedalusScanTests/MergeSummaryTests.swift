import XCTest
@testable import DaedalusScanCore

@MainActor
final class MergeSummaryTests: XCTestCase {
    func testMergeSummaryCountsChangeTypes() throws {
        let harness = try makeHarness()
        let editedComponentID = try captureEvidence(in: harness.viewModel, visitID: harness.visitID)
        let deletedComponentID = try captureEvidence(in: harness.viewModel, visitID: harness.visitID)
        harness.viewModel.confirmCapturedEvidence(for: harness.visitID)

        harness.viewModel.updateEvidenceBundle(
            componentID: editedComponentID,
            visitID: harness.visitID,
            subtype: .systemBoiler,
            areaID: harness.viewModel.visit(id: harness.visitID)?.areas.first?.id,
            geometryID: "wall-west-02",
            approximatePositionLabel: "Above counter",
            voiceNoteTranscript: "Voice Note: edited.",
            photoEvidenceLabel: "Edited picture"
        )
        harness.viewModel.deleteEvidenceBundle(componentID: deletedComponentID, visitID: harness.visitID)

        let summary = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID)?.mergeSummary)
        XCTAssertEqual(summary.addedComponents, 1)
        XCTAssertEqual(summary.editedEvidence, 3)
        XCTAssertEqual(summary.deletedEvidence, 3)
        XCTAssertEqual(summary.needsReviewEvidence, 3)
        XCTAssertEqual(summary.confirmedEvidence, 0)
    }

    func testVersionPreviewIsCurrentToNextVersion() {
        let visit = Visit(reference: "42 Elm Street", twinKind: .system, twinVersion: 7)

        XCTAssertEqual(visit.mergeSummary.currentVersion, 7)
        XCTAssertEqual(visit.mergeSummary.nextVersion, 8)
    }

    func testUnreviewedWarningAppearsInMergeSummary() {
        let visit = Visit(
            reference: "42 Elm Street",
            twinKind: .system,
            components: [
                SystemComponent(
                    kind: .boiler,
                    canonicalSubtype: .combiBoiler,
                    evidence: [Evidence(kind: .photo, localFileName: "photo.jpg", reviewStatus: .needsReview)]
                )
            ]
        )

        XCTAssertTrue(visit.mergeSummary.hasUnreviewedEvidence)
        XCTAssertEqual(visit.mergeSummary.needsReviewEvidence, 1)
    }

    private struct Harness {
        let viewModel: VisitListViewModel
        let visitID: UUID
    }

    private func makeHarness() throws -> Harness {
        let storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaedalusMergeSummary-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: storageDirectory)
        }
        let viewModel = VisitListViewModel(repository: VisitRepository(storageDirectory: storageDirectory))
        let visitID = try XCTUnwrap(viewModel.createVisit(reference: "42 Elm Street"))
        viewModel.advanceLifecycle(.pull, for: visitID)
        viewModel.addRoom(to: visitID, named: "Utility")
        return Harness(viewModel: viewModel, visitID: visitID)
    }

    private func captureEvidence(in viewModel: VisitListViewModel, visitID: UUID) throws -> UUID {
        let areaID = try XCTUnwrap(viewModel.visit(id: visitID)?.areas.first?.id)
        return try XCTUnwrap(
            viewModel.addAREvidenceCapture(
                to: visitID,
                subtype: .combiBoiler,
                areaID: areaID,
                placement: SpatialPlacement(captureState: .areaReferenceOnly, confidence: .low),
                photoData: Data([0xFF, 0xD8]),
                voiceNoteText: "Voice Note: boiler nameplate visible.",
                includeGeometry: true,
                floorLevel: "Ground floor",
                geometryID: "wall-east-01",
                approximatePositionLabel: "Left of cylinder"
            )
        )
    }
}
