import XCTest
@testable import DaedalusScanCore

@MainActor
final class EvidenceBundleEditingTests: XCTestCase {
    func testEditingEvidenceBundleMarksEvidenceNeedsReview() throws {
        let harness = try makeHarness()
        let componentID = try captureConfirmedBundle(in: harness.viewModel, visitID: harness.visitID)
        let newAreaID = try addArea(named: "Landing", in: harness.viewModel, visitID: harness.visitID)

        harness.viewModel.updateEvidenceBundle(
            componentID: componentID,
            visitID: harness.visitID,
            subtype: .systemBoiler,
            areaID: newAreaID,
            geometryID: "wall-west-02",
            approximatePositionLabel: "Above counter",
            voiceNoteTranscript: "Voice Note: edited location after recapture.",
            photoEvidenceLabel: "Edited nameplate picture"
        )

        let component = try XCTUnwrap(harness.viewModel.component(visitID: harness.visitID, componentID: componentID))
        XCTAssertEqual(component.canonicalSubtype, .systemBoiler)
        XCTAssertEqual(component.componentAttributes["areaEvidence"], "Landing")
        XCTAssertEqual(component.spatialContext?.geometryID, "wall-west-02")
        XCTAssertEqual(component.spatialContext?.approximatePositionLabel, "Above counter")
        XCTAssertEqual(component.componentAttributes["voiceNoteTranscript"], "Voice Note: edited location after recapture.")
        XCTAssertEqual(component.componentAttributes["photoEvidenceLabel"], "Edited nameplate picture")
        XCTAssertTrue(component.evidence.allSatisfy { $0.reviewStatus == .needsReview })
        XCTAssertEqual(component.evidenceBundleStatus, .needsReview)
    }

    func testDeletingEvidenceBundleRemovesItFromReview() throws {
        let harness = try makeHarness()
        let componentID = try captureConfirmedBundle(in: harness.viewModel, visitID: harness.visitID)
        XCTAssertEqual(harness.viewModel.visit(id: harness.visitID)?.captureReviewEvidenceGroups.count, 1)

        harness.viewModel.deleteEvidenceBundle(componentID: componentID, visitID: harness.visitID)

        let visit = try XCTUnwrap(harness.viewModel.visit(id: harness.visitID))
        XCTAssertNil(harness.viewModel.component(visitID: harness.visitID, componentID: componentID))
        XCTAssertTrue(visit.captureReviewEvidenceGroups.isEmpty)
        XCTAssertTrue(visit.relationships.allSatisfy { $0.sourceComponentID != componentID && $0.targetComponentID != componentID })
    }

    func testConfirmingEditedEvidenceClearsReviewState() throws {
        let harness = try makeHarness()
        let componentID = try captureConfirmedBundle(in: harness.viewModel, visitID: harness.visitID)

        harness.viewModel.updateEvidenceBundle(
            componentID: componentID,
            visitID: harness.visitID,
            subtype: .combiBoiler,
            areaID: harness.viewModel.visit(id: harness.visitID)?.areas.first?.id,
            geometryID: "wall-east-03",
            approximatePositionLabel: "Right of cylinder",
            voiceNoteTranscript: "Voice Note: edited anchor.",
            photoEvidenceLabel: "Edited picture"
        )
        XCTAssertEqual(harness.viewModel.component(visitID: harness.visitID, componentID: componentID)?.evidenceBundleStatus, .needsReview)

        harness.viewModel.confirmCapturedEvidence(for: harness.visitID)

        let component = try XCTUnwrap(harness.viewModel.component(visitID: harness.visitID, componentID: componentID))
        XCTAssertTrue(component.evidence.allSatisfy { $0.reviewStatus == .confirmed })
        XCTAssertEqual(component.evidenceBundleStatus, .confirmed)
    }

    private struct Harness {
        let viewModel: VisitListViewModel
        let visitID: UUID
    }

    private func makeHarness() throws -> Harness {
        let storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaedalusEvidenceEditing-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: storageDirectory)
        }
        let viewModel = VisitListViewModel(repository: VisitRepository(storageDirectory: storageDirectory))
        let visitID = try XCTUnwrap(viewModel.createVisit(reference: "42 Elm Street"))
        viewModel.advanceLifecycle(.pull, for: visitID)
        return Harness(viewModel: viewModel, visitID: visitID)
    }

    private func captureConfirmedBundle(in viewModel: VisitListViewModel, visitID: UUID) throws -> UUID {
        let areaID = try addArea(named: "Utility", in: viewModel, visitID: visitID)
        let componentID = try XCTUnwrap(
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
        viewModel.confirmCapturedEvidence(for: visitID)
        return componentID
    }

    private func addArea(named name: String, in viewModel: VisitListViewModel, visitID: UUID) throws -> UUID {
        viewModel.addRoom(to: visitID, named: name)
        return try XCTUnwrap(viewModel.visit(id: visitID)?.areas.last?.id)
    }
}
