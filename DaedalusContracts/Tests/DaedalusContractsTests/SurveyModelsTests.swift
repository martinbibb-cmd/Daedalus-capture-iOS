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

    func testVisitPackageRoundTripPreservesRoomsSurveyAndEvidence() throws {
        let textBytes = Data("Good insulation observed.".utf8)
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
        let visit = Visit(reference: "VIS-001", twinKind: .home, rooms: [room])
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
    }
}
