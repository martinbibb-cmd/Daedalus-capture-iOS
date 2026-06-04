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
        let component = SystemComponent(kind: .flue, name: "Balanced flue")
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
    }

    func testVisitPackageRoundTripPreservesRoomsComponentsSurveyAndEvidence() throws {
        let textBytes = Data("Good insulation observed.".utf8)
        let componentTextBytes = Data("Existing appliance photographed and noted.".utf8)
        let room = Room(
            name: "Kitchen",
            survey: [
                "heating.emitters.present": SurveyResponse(booleanValue: true),
                "ventilation.extract.count": SurveyResponse(numericValue: 2)
            ],
            evidence: [
                Evidence(kind: .photo, localFileName: "kitchen-photo.jpg", embeddedData: Data([0xFF, 0xD8])),
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
            evidence: [
                Evidence(kind: .photo, localFileName: "boiler-photo.jpg", embeddedData: Data([0xFF, 0xD8])),
                Evidence(kind: .textNote, localFileName: "boiler-note.txt", embeddedData: componentTextBytes)
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
        XCTAssertEqual(decodedEvidence[2].embeddedData, textBytes)
        XCTAssertEqual(decoded.visits[0].rooms[0].survey["ventilation.extract.count"]?.numericValue, 2)
        XCTAssertEqual(decoded.visits[0].components.count, 1)
        XCTAssertEqual(decoded.visits[0].components[0].kind, .boiler)
        XCTAssertEqual(decoded.visits[0].components[0].notes, "Observed in utility area.")
        XCTAssertEqual(decoded.visits[0].components[0].evidence[1].embeddedData, componentTextBytes)
    }
}
