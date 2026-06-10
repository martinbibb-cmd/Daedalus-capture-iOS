import XCTest
@testable import DaedalusScanCore

@MainActor
final class CaptureLifecycleSmokeTests: XCTestCase {
    func testPropertyTwinCaptureEvidenceReviewConfirmMergeSmokePath() throws {
        let storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaedalusCaptureSmoke-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: storageDirectory)
        }

        let repository = VisitRepository(storageDirectory: storageDirectory)
        let viewModel = VisitListViewModel(repository: repository)

        let visitID = try XCTUnwrap(viewModel.createVisit(reference: "42 Elm Street"))
        viewModel.advanceLifecycle(.pull, for: visitID)

        var workingTwin = try XCTUnwrap(viewModel.visit(id: visitID))
        XCTAssertEqual(workingTwin.reference, "42 Elm Street")
        XCTAssertEqual(workingTwin.repositoryState, .localWorkingCopy)
        XCTAssertEqual(workingTwin.lifecycleStage, .pull)

        viewModel.addRoom(to: visitID, named: "Utility")
        let areaID = try XCTUnwrap(viewModel.visit(id: visitID)?.areas.first?.id)

        let componentID = try XCTUnwrap(
            viewModel.addAREvidenceCapture(
                to: visitID,
                subtype: .combiBoiler,
                areaID: areaID,
                placement: SpatialPlacement(captureState: .areaReferenceOnly, confidence: .low),
                photoData: Data([0xFF, 0xD8, 0xFF]),
                voiceNoteText: "Voice Note: boiler nameplate visible above worktop.",
                includeGeometry: true,
                floorLevel: "Ground floor",
                geometryID: "wall-east-01",
                approximatePositionLabel: "Left of cylinder"
            )
        )

        var component = try XCTUnwrap(viewModel.component(visitID: visitID, componentID: componentID))
        XCTAssertEqual(component.canonicalSubtype, .combiBoiler)
        XCTAssertEqual(component.componentAttributes["componentTypeEvidence"], "Combi Boiler")
        XCTAssertEqual(component.componentAttributes["areaEvidence"], "Utility")
        XCTAssertEqual(component.componentAttributes["geometryEvidence"], "Selected geometry captured in AR Capture.")
        XCTAssertEqual(component.spatialContext?.floorLevel, "Ground floor")
        XCTAssertEqual(component.spatialContext?.areaLabel, "Utility")
        XCTAssertEqual(component.spatialContext?.geometryID, "wall-east-01")
        XCTAssertEqual(component.spatialContext?.approximatePositionLabel, "Left of cylinder")
        XCTAssertEqual(Set(component.evidence.map(\.kind)), Set([.photo, .voiceNote, .textNote]))
        XCTAssertTrue(component.evidence.allSatisfy { $0.reviewStatus == .needsReview })

        workingTwin = try XCTUnwrap(viewModel.visit(id: visitID))
        let reviewGroup = try XCTUnwrap(workingTwin.captureReviewEvidenceGroups.first)
        XCTAssertEqual(reviewGroup.id, componentID)
        XCTAssertTrue(reviewGroup.title.contains("Combi Boiler"))
        XCTAssertTrue(reviewGroup.title.contains("Ground floor"))
        XCTAssertEqual(reviewGroup.spatialContext, "Ground floor / Utility / wall-east-01 / Left of cylinder")
        XCTAssertTrue(reviewGroup.cards.contains { $0.title == "Picture" && $0.reviewStatus == .needsReview })
        XCTAssertTrue(reviewGroup.cards.contains { $0.title == "Voice Note" && $0.reviewStatus == .needsReview })
        XCTAssertTrue(reviewGroup.cards.contains { $0.title == "Geometry" && $0.reviewStatus == .needsReview })
        XCTAssertTrue(reviewGroup.cards.contains { $0.title == "Area / Location" && $0.detail == "Utility" })

        viewModel.setComponentReviewStatus(.needsReview, componentID: componentID, visitID: visitID)
        viewModel.confirmCapturedEvidence(for: visitID)

        component = try XCTUnwrap(viewModel.component(visitID: visitID, componentID: componentID))
        XCTAssertEqual(component.reviewStatus, .needsReview)
        XCTAssertTrue(component.evidence.allSatisfy { $0.reviewStatus == .confirmed })

        viewModel.setComponentReviewStatus(nil, componentID: componentID, visitID: visitID)
        let versionBeforeMerge = try XCTUnwrap(viewModel.visit(id: visitID)?.twinVersion)
        viewModel.advanceLifecycle(.merge, for: visitID)

        let mergedTwin = try XCTUnwrap(viewModel.visit(id: visitID))
        XCTAssertEqual(mergedTwin.repositoryState, .merged)
        XCTAssertEqual(mergedTwin.lifecycleStage, .merge)
        XCTAssertEqual(mergedTwin.twinVersion, versionBeforeMerge + 1)
        XCTAssertNotNil(mergedTwin.lastMergedAt)

        let mergedComponent = try XCTUnwrap(mergedTwin.components.first { $0.id == componentID })
        XCTAssertTrue(mergedComponent.evidence.allSatisfy { $0.reviewStatus == .confirmed })
        XCTAssertEqual(mergedComponent.spatialContext?.displaySummary, "Ground floor / Utility / wall-east-01 / Left of cylinder")

        let package = DaedalusPackageExporter.makePackage(from: mergedTwin, source: VisitPackageMetadata.canonicalSource)
        let payload = try encodedPayload(package)
        XCTAssertNoForbiddenBoundaryLanguage(in: payload)
    }

    private func encodedPayload<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        return try XCTUnwrap(String(data: data, encoding: .utf8))
    }

    private func XCTAssertNoForbiddenBoundaryLanguage(
        in payload: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let forbiddenTerms = [
            "recommendation",
            "recommended",
            "bestOption",
            "best option",
            "suitability",
            "ranking",
            "pricing",
            "quoteSelection",
            "productSelection"
        ]
        let lowercasedPayload = payload.lowercased()
        let findings = forbiddenTerms.filter { lowercasedPayload.contains($0.lowercased()) }
        XCTAssertEqual(findings, [], file: file, line: line)
    }
}
