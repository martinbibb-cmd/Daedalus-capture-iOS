import XCTest
@testable import DaedalusScanCore

@MainActor
final class CaptureLiteTests: XCTestCase {
    func testLiteCaptureCreatesSameEvidenceBundleShape() throws {
        let harness = try makeHarness()
        let componentID = try captureLiteEvidence(in: harness.viewModel, visitID: harness.visitID)

        let component = try XCTUnwrap(harness.viewModel.component(visitID: harness.visitID, componentID: componentID))
        XCTAssertEqual(component.componentAttributes["captureSource"], "Capture Lite")
        XCTAssertEqual(component.componentAttributes["componentTypeEvidence"], "Combi Boiler")
        XCTAssertEqual(component.componentAttributes["areaEvidence"], "Utility")
        XCTAssertEqual(component.componentAttributes["photoEvidenceLabel"], "Lite picture")
        XCTAssertEqual(component.componentAttributes["voiceNoteTranscript"], "Voice Note: Lite capture.")
        XCTAssertEqual(Set(component.evidence.map(\.kind)), Set([.photo, .voiceNote]))
        XCTAssertTrue(component.evidence.allSatisfy { $0.reviewStatus == .needsReview })
    }

    func testLiteEvidenceAppearsInReviewTimelineAndMergeSummary() throws {
        let harness = try makeHarness()
        let componentID = try captureLiteEvidence(in: harness.viewModel, visitID: harness.visitID)
        let visit = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID))

        let reviewGroup = try XCTUnwrap(visit.captureReviewEvidenceGroups.first { $0.id == componentID })
        XCTAssertTrue(reviewGroup.cards.contains { $0.title == "Picture" && $0.detail == "Lite picture" })
        XCTAssertTrue(reviewGroup.cards.contains { $0.title == "Voice Note" && $0.detail == "Voice Note: Lite capture." })
        XCTAssertEqual(visit.evidenceTimelineEntries(componentID: componentID).count, 2)
        XCTAssertEqual(visit.mergeSummary.needsReviewEvidence, 2)
    }

    func testLiteEvidenceCanBeConfirmedAndMerged() throws {
        let harness = try makeHarness()
        let componentID = try captureLiteEvidence(in: harness.viewModel, visitID: harness.visitID)

        harness.viewModel.confirmCapturedEvidence(for: harness.visitID)
        harness.viewModel.requestMergeTwin(for: harness.visitID)

        let visit = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID))
        let component = try XCTUnwrap(harness.viewModel.component(visitID: harness.visitID, componentID: componentID))
        XCTAssertEqual(visit.repositoryState, .merged)
        XCTAssertEqual(visit.twinVersion, 2)
        XCTAssertTrue(component.evidence.allSatisfy { $0.reviewStatus == .confirmed })
        XCTAssertTrue(visit.evidenceTimelineEntries(componentID: componentID).allSatisfy(\.isMerged))
    }

    private struct Harness {
        let viewModel: VisitListViewModel
        let visitID: UUID
    }

    private func makeHarness() throws -> Harness {
        let storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaedalusLite-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: storageDirectory)
        }
        let viewModel = VisitListViewModel(repository: VisitRepository(storageDirectory: storageDirectory))
        let visitID = try XCTUnwrap(viewModel.createVisit(reference: "42 Elm Street"))
        viewModel.advanceLifecycle(.pull, for: visitID)
        viewModel.addRoom(to: visitID, named: "Utility")
        return Harness(viewModel: viewModel, visitID: visitID)
    }

    private func captureLiteEvidence(in viewModel: VisitListViewModel, visitID: UUID) throws -> UUID {
        let areaID = try XCTUnwrap(viewModel.visit(id: visitID)?.areas.first?.id)
        return try XCTUnwrap(
            viewModel.addCaptureLiteEvidenceCapture(
                to: visitID,
                subtype: .combiBoiler,
                areaID: areaID,
                photoData: Data([0xFF, 0xD8]),
                voiceNoteText: "Voice Note: Lite capture.",
                photoEvidenceLabel: "Lite picture"
            )
        )
    }
}
