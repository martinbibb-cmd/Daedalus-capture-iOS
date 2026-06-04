import XCTest
@testable import DaedalusContracts

final class SurveyModelsTests: XCTestCase {
    func testSurveyResponseAnsweredForEachQuestionKind() {
        let booleanQuestion = SurveyQuestion(key: "bool", label: "Bool", kind: .boolean)
        let choiceQuestion = SurveyQuestion(key: "choice", label: "Choice", kind: .singleChoice, allowedValues: ["A"])
        let numericQuestion = SurveyQuestion(key: "number", label: "Number", kind: .numeric)

        XCTAssertTrue(SurveyResponse(booleanValue: true).isAnswered(for: booleanQuestion))
        XCTAssertTrue(SurveyResponse(selectedValue: "A").isAnswered(for: choiceQuestion))
        XCTAssertTrue(SurveyResponse(numericValue: 2).isAnswered(for: numericQuestion))
        XCTAssertFalse(SurveyResponse().isAnswered(for: numericQuestion))
    }

    func testCanonicalOrderCoversAllSystemComponentKinds() {
        let canonical = Set(SystemComponentKind.canonicalOrder)
        let all = Set(SystemComponentKind.allCases)
        XCTAssertEqual(canonical, all, "canonicalOrder must include every SystemComponentKind case")
        XCTAssertEqual(SystemComponentKind.canonicalOrder.count, all.count, "canonicalOrder must not have duplicates")
    }

    func testFlueRoundTrips() throws {
        let component = SystemComponent(
            kind: .flue,
            name: "Balanced flue",
            componentAttributes: [
                "terminalLocation": "Rear elevation",
                "approximateRoute": "Observed rising vertically before exiting"
            ]
        )
        let visit = Visit(reference: "VIS-FLUE", twinKind: .system, components: [component])
        let package = VisitPackage(visits: [visit])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(package)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(VisitPackage.self, from: data)
        XCTAssertEqual(decoded.visits[0].components[0].kind, .flue)
        XCTAssertEqual(decoded.visits[0].components[0].name, "Balanced flue")
        XCTAssertEqual(decoded.visits[0].components[0].componentAttributes["terminalLocation"], "Rear elevation")
        XCTAssertEqual(decoded.visits[0].components[0].componentAttributes["approximateRoute"], "Observed rising vertically before exiting")
    }

    func testVisitPackageRoundTripPreservesRoomsComponentsSurveyAndEvidence() throws {
        let textBytes = Data("Good insulation observed.".utf8)
        let componentTextBytes = Data("Existing appliance photographed and noted.".utf8)
        let room = Room(
            name: "Kitchen",
            reviewStatus: .confirmed,
            reviewNotes: "Room details verified.",
            survey: [
                "heating.emitters.present": SurveyResponse(
                    booleanValue: true,
                    reviewStatus: .needsReview,
                    reviewNotes: "Double-check emitter count."
                ),
                "ventilation.extract.count": SurveyResponse(numericValue: 2, reviewStatus: .draft)
            ],
            evidence: [
                Evidence(
                    kind: .photo,
                    localFileName: "kitchen-photo.jpg",
                    reviewStatus: .needsReview,
                    reviewNotes: "Possible obstructions in frame.",
                    embeddedData: Data([0xFF, 0xD8])
                ),
                Evidence(kind: .voiceNote, localFileName: "kitchen-note.m4a", embeddedData: Data([0x00, 0x01])),
                Evidence(kind: .textNote, localFileName: "kitchen-note.txt", embeddedData: textBytes)
            ]
        )
        let component = SystemComponent(
            kind: .boiler,
            name: "Main boiler",
            manufacturer: "Acme",
            model: "X100",
            notes: "Observed in utility area.",
            reviewStatus: .confirmed,
            reviewNotes: "Visual checks complete.",
            componentAttributes: [
                "fuelType": "Natural gas",
                "boilerType": "Combi",
                "approximateAge": "Around 10 years",
                "location": "Utility area",
                "fluePositionNotes": "Observed exiting at rear wall",
                "visibleConditionNotes": "No obvious casing damage noted"
            ],
            evidence: [
                Evidence(kind: .photo, localFileName: "boiler-photo.jpg", embeddedData: Data([0xFF, 0xD8])),
                Evidence(
                    kind: .textNote,
                    localFileName: "boiler-note.txt",
                    reviewStatus: .rejected,
                    reviewNotes: "Comment references wrong appliance.",
                    embeddedData: componentTextBytes
                )
            ]
        )
        let visit = Visit(reference: "VIS-001", twinKind: .home, rooms: [room], components: [component])
        let package = VisitPackage(visits: [visit])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(package)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(VisitPackage.self, from: data)

        XCTAssertEqual(decoded.visits.count, 1)
        XCTAssertEqual(decoded.visits[0].reference, "VIS-001")
        let decodedEvidence = decoded.visits[0].rooms[0].evidence
        XCTAssertEqual(decodedEvidence.map(\.kind), [.photo, .voiceNote, .textNote])
        XCTAssertEqual(decodedEvidence[0].embeddedData, Data([0xFF, 0xD8]))
        XCTAssertEqual(decodedEvidence[0].reviewStatus, .needsReview)
        XCTAssertEqual(decodedEvidence[0].reviewNotes, "Possible obstructions in frame.")
        XCTAssertEqual(decodedEvidence[2].embeddedData, textBytes)
        XCTAssertEqual(decoded.visits[0].rooms[0].reviewStatus, .confirmed)
        XCTAssertEqual(decoded.visits[0].rooms[0].reviewNotes, "Room details verified.")
        XCTAssertEqual(decoded.visits[0].rooms[0].survey["heating.emitters.present"]?.reviewStatus, .needsReview)
        XCTAssertEqual(decoded.visits[0].rooms[0].survey["heating.emitters.present"]?.reviewNotes, "Double-check emitter count.")
        XCTAssertEqual(decoded.visits[0].rooms[0].survey["ventilation.extract.count"]?.numericValue, 2)
        XCTAssertEqual(decoded.visits[0].components.count, 1)
        XCTAssertEqual(decoded.visits[0].components[0].kind, .boiler)
        XCTAssertEqual(decoded.visits[0].components[0].notes, "Observed in utility area.")
        XCTAssertEqual(decoded.visits[0].components[0].reviewStatus, .confirmed)
        XCTAssertEqual(decoded.visits[0].components[0].reviewNotes, "Visual checks complete.")
        XCTAssertEqual(decoded.visits[0].components[0].componentAttributes["fuelType"], "Natural gas")
        XCTAssertEqual(decoded.visits[0].components[0].componentAttributes["visibleConditionNotes"], "No obvious casing damage noted")
        XCTAssertEqual(decoded.visits[0].components[0].evidence[1].embeddedData, componentTextBytes)
        XCTAssertEqual(decoded.visits[0].components[0].evidence[1].reviewStatus, .rejected)
        XCTAssertEqual(decoded.visits[0].components[0].evidence[1].reviewNotes, "Comment references wrong appliance.")
    }

    func testVisitPackageDefaultsIncludeMetadata() throws {
        let visit = Visit(reference: "VIS-META", twinKind: .home)
        let package = VisitPackage(visits: [visit])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(package)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(VisitPackage.self, from: data)

        XCTAssertNotNil(decoded.metadata)
        XCTAssertEqual(decoded.metadata?.schemaVersion, 1)
        XCTAssertEqual(decoded.metadata?.source, "Daedalus Scan")
        XCTAssertEqual(decoded.metadata?.exportedByApp, "Daedalus Scan")
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.exportedAt, decoded.metadata?.createdAt)
    }

    func testVisitPackageDecodesLegacyPayloadWithoutMetadata() throws {
        let json = """
        {
          "schemaVersion": 1,
          "exportedAt": "2024-01-01T00:00:00Z",
          "visits": [
            {
              "id": "00000000-0000-0000-0000-000000000001",
              "reference": "VIS-LEGACY-PACKAGE",
              "createdAt": "2024-01-01T00:00:00Z",
              "twinKind": "home",
              "rooms": [],
              "components": []
            }
          ]
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let package = try decoder.decode(VisitPackage.self, from: Data(json.utf8))

        XCTAssertNil(package.metadata)
        XCTAssertEqual(package.schemaVersion, 1)
        XCTAssertEqual(package.visits.count, 1)
        XCTAssertEqual(package.visits[0].reference, "VIS-LEGACY-PACKAGE")
    }

    func testSectionStatusRoundTripThroughVisitPackage() throws {
        var visit = Visit(reference: "VIS-STATUS", twinKind: .system)
        visit.sectionStatuses = [
            .flue: .notAccessible,
            .cylinder: .present,
            .feedAndExpansion: .notPresent
        ]
        let package = VisitPackage(visits: [visit])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(package)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(VisitPackage.self, from: data)

        XCTAssertEqual(decoded.visits[0].sectionStatuses[.flue], .notAccessible)
        XCTAssertEqual(decoded.visits[0].sectionStatuses[.cylinder], .present)
        XCTAssertEqual(decoded.visits[0].sectionStatuses[.feedAndExpansion], .notPresent)
        XCTAssertNil(decoded.visits[0].sectionStatuses[.boiler])
    }

    func testSectionStatusDecodesFromLegacyVisitWithNoSectionStatuses() throws {
        // Simulate a Visit encoded without sectionStatuses (legacy format)
        let json = "[{\"id\":\"00000000-0000-0000-0000-000000000001\",\"reference\":\"VIS-LEGACY\",\"createdAt\":\"2024-01-01T00:00:00Z\",\"twinKind\":\"system\",\"rooms\":[],\"components\":[]}]"
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let visits = try decoder.decode([Visit].self, from: Data(json.utf8))
        XCTAssertEqual(visits[0].sectionStatuses, [:])
    }

    func testComponentAttributesRoundTripForMultipleKinds() throws {
        let visit = Visit(
            reference: "VIS-ATTR",
            twinKind: .system,
            components: [
                SystemComponent(
                    kind: .boiler,
                    name: "Boiler",
                    componentAttributes: [
                        "fuelType": "LPG",
                        "boilerType": "Regular",
                        "location": "Kitchen"
                    ]
                ),
                SystemComponent(
                    kind: .flue,
                    name: "Flue",
                    componentAttributes: [
                        "terminalLocation": "Side wall",
                        "plumeNotes": "Light plume observed"
                    ]
                ),
                SystemComponent(
                    kind: .gasMeter,
                    name: "Meter",
                    componentAttributes: [
                        "location": "External box",
                        "visibleECV": "Observed",
                        "bondingObserved": "Unknown"
                    ]
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(VisitPackage(visits: [visit]))

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(VisitPackage.self, from: data)

        XCTAssertEqual(decoded.visits[0].components[0].componentAttributes["fuelType"], "LPG")
        XCTAssertEqual(decoded.visits[0].components[1].componentAttributes["plumeNotes"], "Light plume observed")
        XCTAssertEqual(decoded.visits[0].components[2].componentAttributes["visibleECV"], "Observed")
        XCTAssertEqual(decoded.visits[0].components[2].componentAttributes["bondingObserved"], "Unknown")
    }

    func testSystemComponentDecodesFromLegacyPayloadWithoutComponentAttributes() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000002",
          "kind": "boiler",
          "name": "Legacy boiler",
          "manufacturer": "",
          "model": "",
          "notes": "Observed previously",
          "evidence": []
        }
        """
        let decoder = JSONDecoder()
        let component = try decoder.decode(SystemComponent.self, from: Data(json.utf8))
        XCTAssertEqual(component.kind, .boiler)
        XCTAssertEqual(component.componentAttributes, [:])
        XCTAssertNil(component.reviewStatus)
        XCTAssertNil(component.reviewNotes)
    }

    func testLegacyRoomSurveyAndEvidenceDecodeWithoutReviewFields() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000003",
          "name": "Legacy room",
          "survey": {
            "heating.emitters.present": {
              "booleanValue": true
            }
          },
          "evidence": [
            {
              "id": "00000000-0000-0000-0000-000000000004",
              "kind": "photo",
              "localFileName": "legacy-photo.jpg",
              "createdAt": "2024-01-01T00:00:00Z"
            }
          ]
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let room = try decoder.decode(Room.self, from: Data(json.utf8))
        XCTAssertNil(room.reviewStatus)
        XCTAssertNil(room.reviewNotes)
        XCTAssertNil(room.survey["heating.emitters.present"]?.reviewStatus)
        XCTAssertNil(room.survey["heating.emitters.present"]?.reviewNotes)
        XCTAssertNil(room.evidence.first?.reviewStatus)
        XCTAssertNil(room.evidence.first?.reviewNotes)
    }
}
