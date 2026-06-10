import XCTest
@testable import DaedalusScanCore

@MainActor
final class CaptureSessionStateTests: XCTestCase {
    func testUnreviewedEvidenceProducesWarningState() throws {
        let harness = try makeHarness()
        let componentID = try captureEvidence(in: harness.viewModel, visitID: harness.visitID)

        let visit = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID))
        XCTAssertEqual(visit.captureSessionStatus, .hasUnreviewedEvidence)
        XCTAssertTrue(visit.hasUnreviewedEvidence)
        XCTAssertTrue(visit.shouldWarnBeforeMerge)
        XCTAssertTrue(visit.shouldWarnBeforeLeavingWorkingTwin)

        harness.viewModel.requestMergeTwin(for: harness.visitID)
        XCTAssertEqual(harness.viewModel.pendingWorkingTwinWarning?.kind, .mergeWithUnreviewedEvidence)
        XCTAssertNotNil(harness.viewModel.component(visitID: harness.visitID, componentID: componentID))
    }

    func testConfirmedEvidenceProducesReadyToMergeState() throws {
        let harness = try makeHarness()
        _ = try captureEvidence(in: harness.viewModel, visitID: harness.visitID)

        harness.viewModel.confirmCapturedEvidence(for: harness.visitID)

        let visit = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID))
        XCTAssertEqual(visit.captureSessionStatus, .readyToMerge)
        XCTAssertFalse(visit.hasUnreviewedEvidence)
        XCTAssertFalse(visit.shouldWarnBeforeMerge)
        XCTAssertTrue(visit.shouldWarnBeforeLeavingWorkingTwin)
    }

    func testMergeClearsDirtyState() throws {
        let harness = try makeHarness()
        _ = try captureEvidence(in: harness.viewModel, visitID: harness.visitID)
        harness.viewModel.confirmCapturedEvidence(for: harness.visitID)

        harness.viewModel.requestMergeTwin(for: harness.visitID)

        let visit = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID))
        XCTAssertEqual(visit.captureSessionStatus, .merged)
        XCTAssertEqual(visit.repositoryState, .merged)
        XCTAssertFalse(visit.hasUnmergedLocalWork)
        XCTAssertFalse(visit.shouldWarnBeforeLeavingWorkingTwin)
    }

    func testPullingWithLocalChangesIsGuarded() throws {
        let harness = try makeHarness()
        harness.viewModel.addRoom(to: harness.visitID, named: "Utility")

        harness.viewModel.requestPullTwin(for: harness.visitID)

        XCTAssertEqual(harness.viewModel.pendingWorkingTwinWarning?.kind, .pullWouldReplaceLocalChanges)
        XCTAssertEqual(harness.viewModel.pendingWorkingTwinWarning?.action, .pull)
        XCTAssertEqual(harness.viewModel.visit(id: harness.visitID)?.lifecycleStage, .capture)

        harness.viewModel.confirmPendingWorkingTwinWarning()

        XCTAssertNil(harness.viewModel.pendingWorkingTwinWarning)
        XCTAssertEqual(harness.viewModel.visit(id: harness.visitID)?.lifecycleStage, .pull)
    }

    private struct Harness {
        let storageDirectory: URL
        let viewModel: VisitListViewModel
        let visitID: UUID
    }

    private func makeHarness() throws -> Harness {
        let storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaedalusCaptureSession-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: storageDirectory)
        }
        let viewModel = VisitListViewModel(repository: VisitRepository(storageDirectory: storageDirectory))
        let visitID = try XCTUnwrap(viewModel.createVisit(reference: "42 Elm Street"))
        viewModel.advanceLifecycle(.pull, for: visitID)
        return Harness(storageDirectory: storageDirectory, viewModel: viewModel, visitID: visitID)
    }

    private func captureEvidence(in viewModel: VisitListViewModel, visitID: UUID) throws -> UUID {
        viewModel.addRoom(to: visitID, named: "Utility")
        let areaID = try XCTUnwrap(viewModel.visit(id: visitID)?.areas.first?.id)
        return try XCTUnwrap(
            viewModel.addAREvidenceCapture(
                to: visitID,
                subtype: .combiBoiler,
                areaID: areaID,
                placement: SpatialPlacement(captureState: .areaReferenceOnly, confidence: .low),
                photoData: Data([0xFF, 0xD8, 0xFF]),
                voiceNoteText: "Voice Note: boiler nameplate visible.",
                includeGeometry: true,
                floorLevel: "Ground floor",
                geometryID: "wall-east-01",
                approximatePositionLabel: "Left of cylinder"
            )
        )
    }
}
