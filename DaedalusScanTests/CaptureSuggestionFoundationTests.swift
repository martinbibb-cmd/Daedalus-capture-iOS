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

    func testSuggestedAreaFoundationDefinesRequestedReviewStatesAndCategories() {
        XCTAssertEqual(
            SuggestedAreaReviewState.allCases,
            [.suggested, .confirmed, .renamed, .merged, .ignored, .unresolved]
        )
        XCTAssertEqual(
            SuggestedAreaCategory.allCases,
            [.room, .circulation, .external, .serviceArea, .unresolved]
        )
        XCTAssertEqual(
            Visit.allowedSuggestedAreaNames,
            [
                "Kitchen",
                "Utility",
                "Hall",
                "Landing",
                "Lounge",
                "Dining Room",
                "Bedroom",
                "Bathroom",
                "Ensuite",
                "Airing Cupboard",
                "Loft",
                "Garage",
                "Outside",
                "Unknown Area"
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

        XCTAssertTrue(suggestions.filter { $0.kind == .area }.map(\.title).contains("Utility"))
        XCTAssertEqual(suggestions.filter { $0.kind == .object }.map(\.title), ["Boiler"])
        XCTAssertEqual(suggestions.filter { $0.kind == .specialObject }.map(\.specialObject), [.unresolvedSpecialObject])
        XCTAssertTrue(suggestions.allSatisfy { $0.reviewState == .suggested })
    }

    func testSuggestedAreaGroupsCollectContainedObjectsAndEvidenceWithoutChangingExportModels() {
        let kitchenID = UUID()
        let hallID = UUID()
        let boilerID = UUID()
        let markerID = UUID()
        let boilerEvidenceID = UUID()
        let markerEvidenceID = UUID()

        let visit = Visit(
            reference: "Area review",
            twinKind: .system,
            rooms: [
                Room(id: kitchenID, name: "Kitchen"),
                Room(id: hallID, name: "Hall")
            ],
            relationships: [
                SpatialRelationship(
                    sourceComponentID: boilerID,
                    relationship: .containedIn,
                    targetAreaID: kitchenID
                ),
                SpatialRelationship(
                    sourceComponentID: markerID,
                    relationship: .containedIn,
                    targetAreaID: hallID
                )
            ],
            components: [
                SystemComponent(
                    id: boilerID,
                    kind: .boiler,
                    componentAttributes: [
                        "liveEvidenceKind": LiveCaptureEvidenceKind.photo.rawValue,
                        "suggestedLabel": "Boiler"
                    ],
                    evidence: [
                        Evidence(id: boilerEvidenceID, kind: .photo, localFileName: "boiler.jpg")
                    ]
                ),
                SystemComponent(
                    id: markerID,
                    kind: .other,
                    componentAttributes: [
                        "liveEvidenceKind": LiveCaptureEvidenceKind.mark.rawValue,
                        "suggestedLabel": "Marker"
                    ],
                    evidence: [
                        Evidence(id: markerEvidenceID, kind: .textNote, localFileName: "marker.txt")
                    ]
                )
            ]
        )

        let areaGroups = visit.suggestedAreaGroups
        let kitchen = areaGroups.first { $0.name == "Kitchen" }
        let hall = areaGroups.first { $0.name == "Hall" }

        XCTAssertEqual(kitchen?.category, .room)
        XCTAssertEqual(kitchen?.objectLinks.map(\.objectID), [boilerID])
        XCTAssertEqual(kitchen?.evidenceLinks.map(\.evidenceID), [boilerEvidenceID])
        XCTAssertEqual(hall?.category, .circulation)
        XCTAssertEqual(hall?.objectLinks.map(\.objectID), [markerID])
        XCTAssertEqual(hall?.evidenceLinks.map(\.evidenceID), [markerEvidenceID])
    }

    func testSuggestedAreaGroupsUseSpatialContextFallbackForEvidenceClusters() {
        let radiatorID = UUID()
        let radiatorEvidenceID = UUID()
        let visit = Visit(
            reference: "Spatial fallback",
            twinKind: .system,
            components: [
                SystemComponent(
                    id: radiatorID,
                    kind: .radiator,
                    componentAttributes: [
                        "liveEvidenceKind": LiveCaptureEvidenceKind.photo.rawValue,
                        "suggestedLabel": "Radiator"
                    ],
                    evidence: [
                        Evidence(id: radiatorEvidenceID, kind: .photo, localFileName: "radiator.jpg")
                    ],
                    spatialContext: SpatialEvidenceContext(areaLabel: "Outside")
                )
            ]
        )

        let area = visit.suggestedAreaGroups.first

        XCTAssertEqual(area?.name, "Outside")
        XCTAssertEqual(area?.category, .external)
        XCTAssertEqual(area?.objectCount, 1)
        XCTAssertEqual(area?.evidenceCount, 1)
    }
}
