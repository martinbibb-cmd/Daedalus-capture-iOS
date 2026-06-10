import XCTest
@testable import DaedalusScanCore

@MainActor
final class ComponentMarkerTests: XCTestCase {
    func testMarkersDeriveFromCapturedComponents() throws {
        let harness = try makeHarness()
        let componentID = try captureEvidence(in: harness.viewModel, visitID: harness.visitID)

        let marker = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID)?.componentMarkers.first)
        XCTAssertEqual(marker.componentID, componentID)
        XCTAssertEqual(marker.title, "Combi Boiler")
        XCTAssertEqual(marker.areaLabel, "Utility")
        XCTAssertEqual(marker.positionLabel, "Left of cylinder")
        XCTAssertEqual(marker.reviewStatus, .needsReview)
        XCTAssertFalse(marker.isMerged)
    }

    func testMarkerFiltersShowCorrectMarkers() throws {
        let harness = try makeHarness()
        _ = try captureEvidence(in: harness.viewModel, visitID: harness.visitID)

        var visit = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID))
        XCTAssertEqual(visit.componentMarkers(matching: .all).count, 1)
        XCTAssertEqual(visit.componentMarkers(matching: .needsReview).count, 1)
        XCTAssertEqual(visit.componentMarkers(matching: .merged).count, 0)
        XCTAssertEqual(visit.componentMarkers(matching: .unmerged).count, 1)

        harness.viewModel.confirmCapturedEvidence(for: harness.visitID)
        harness.viewModel.requestMergeTwin(for: harness.visitID)

        visit = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID))
        XCTAssertEqual(visit.componentMarkers(matching: .needsReview).count, 0)
        XCTAssertEqual(visit.componentMarkers(matching: .merged).count, 1)
        XCTAssertEqual(visit.componentMarkers(matching: .unmerged).count, 0)
    }

    func testMarkerCarriesComponentIDForOpeningEvidence() throws {
        let harness = try makeHarness()
        let componentID = try captureEvidence(in: harness.viewModel, visitID: harness.visitID)

        let marker = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID)?.componentMarkers.first)
        let openedComponent = try XCTUnwrap(harness.viewModel.component(visitID: harness.visitID, componentID: marker.componentID))

        XCTAssertEqual(marker.componentID, componentID)
        XCTAssertEqual(openedComponent.id, componentID)
        XCTAssertFalse(openedComponent.evidence.isEmpty)
    }

    private struct Harness {
        let viewModel: VisitListViewModel
        let visitID: UUID
    }

    private func makeHarness() throws -> Harness {
        let storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaedalusMarkers-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: storageDirectory)
        }
        let viewModel = VisitListViewModel(repository: VisitRepository(storageDirectory: storageDirectory))
        let visitID = try XCTUnwrap(viewModel.createVisit(reference: "42 Elm Street"))
        viewModel.advanceLifecycle(.pull, for: visitID)
        return Harness(viewModel: viewModel, visitID: visitID)
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
