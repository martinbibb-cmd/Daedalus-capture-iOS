import XCTest
@testable import DaedalusScanCore

final class CaptureSuggestionFoundationTests: XCTestCase {
    func testSuggestionFoundationDefinesRequestedSourcesStatesAndSpecialObjects() {
        XCTAssertEqual(
            CaptureSuggestionSource.allCases,
            [.machineVision, .transcript, .spatialContext, .manualTap, .existingEvidence]
        )
        XCTAssertEqual(
            CaptureSuggestionReviewState.allCases,
            [.suggested, .confirmed, .changed, .ignored, .unresolved, .needsAttention]
        )
        XCTAssertEqual(
            SpecialObject.allCases,
            [
                .doorway,
                .externalWall,
                .serviceCupboard,
                .airingCupboard,
                .loftHatch,
                .gasEntry,
                .waterEntry,
                .electricIntake,
                .flueExit,
                .hiddenObjectMarker,
                .obscuredRadiator,
                .cylinderAbove,
                .tankAbove,
                .unresolvedSpecialObject
            ]
        )
    }

    func testVisitSuggestionFoundationSeparatesAreasObjectsAndSpecialObjectsFromEvidence() {
        let areaID = UUID()
        let componentID = UUID()
        let visit = Visit(
            reference: "Suggestion scaffold",
            twinKind: .system,
            rooms: [
                Room(
                    id: areaID,
                    name: "Utility",
                    reviewStatus: .needsReview,
                    evidence: [Evidence(kind: .photo, localFileName: "area.jpg")],
                    spatialPlacement: SpatialPlacement(captureState: .approximate, confidence: .medium)
                )
            ],
            components: [
                SystemComponent(
                    id: componentID,
                    kind: .boiler,
                    name: "Photo",
                    reviewStatus: .unreviewed,
                    componentAttributes: [
                        "liveEvidenceKind": LiveCaptureEvidenceKind.photo.rawValue,
                        "suggestedLabel": "Boiler",
                        "reviewDecision": CaptureReviewDecision.unreviewed.rawValue
                    ],
                    evidence: [Evidence(kind: .photo, localFileName: "boiler.jpg")]
                )
            ]
        )

        let suggestions = visit.captureSuggestionFoundation

        XCTAssertEqual(suggestions.filter { $0.kind == .area }.map(\.title), ["Utility"])
        XCTAssertEqual(suggestions.filter { $0.kind == .object }.map(\.title), ["Boiler"])
        XCTAssertEqual(suggestions.filter { $0.kind == .specialObject }.map(\.specialObject), [.unresolvedSpecialObject])
        XCTAssertTrue(suggestions.allSatisfy { $0.reviewState == .suggested })
    }
}
