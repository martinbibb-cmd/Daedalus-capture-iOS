import XCTest
@testable import DaedalusContracts

final class ConstitutionalBoundaryTests: XCTestCase {
    func testObservationBoundaryDoesNotExposeSolutionWorkflowLanguage() throws {
        let forbiddenTerms = [
            "proposedSystem",
            "proposed system",
            "recommendedSystem",
            "recommended system",
            "best option",
            "suitability",
            "ranking"
        ]

        let findings = try scanSourceFiles(terms: forbiddenTerms)
        XCTAssertEqual(findings, [], "Capture contracts must stay observation-first: \(findings.joined(separator: "\n"))")
    }

    func testCaptureExportContainsObservationsEvidenceMeasurementsAndRelationshipsButNoDecisionOutputs() throws {
        let evidence = Evidence(kind: .photo, localFileName: "boiler-nameplate.jpg", reviewStatus: .confirmed)
        let room = Room(name: "Utility", evidence: [evidence], factState: .known)
        let component = SystemComponent(
            kind: .boiler,
            name: "Boiler",
            manufacturer: "Ideal",
            model: "Logic",
            evidence: [evidence],
            factState: .known
        )

        let waterObservation = WaterSupplyObservation(
            observedBy: "Engineer",
            method: .pressureFlowTestKit,
            location: .kitchenColdTap,
            intent: .incomingMainCapacity,
            values: [
                WaterMeasurementValue(name: .flowRate, value: "18", unit: "l/min", confidence: .observed)
            ],
            confidence: .observed,
            evidenceIDs: [evidence.id.uuidString],
            provenance: TwinProvenance(source: VisitPackageMetadata.canonicalSource)
        )

        let servicePoint = ServicePointObservation(
            areaID: room.id.uuidString,
            servicePointType: .kitchenTap,
            supplyType: .mainsCold,
            intendedPressureType: .mainsPressure,
            servedByAssetIDs: [component.id.uuidString],
            observedIssues: [.noIssueObserved],
            evidenceIDs: [evidence.id.uuidString],
            confidence: .observed,
            provenance: TwinProvenance(source: VisitPackageMetadata.canonicalSource)
        )

        let visit = Visit(
            reference: "VIS-BOUNDARY",
            twinKind: .system,
            rooms: [room],
            relationships: [
                SpatialRelationship(
                    sourceComponentID: component.id,
                    relationship: .containedIn,
                    targetAreaID: room.id
                )
            ],
            components: [component],
            waterSupplyObservations: [waterObservation],
            servicePointObservations: [servicePoint]
        )

        let package = DaedalusPackageExporter.makePackage(
            from: visit,
            source: VisitPackageMetadata.canonicalSource
        )
        let payload = try encodedPayload(package)
        let lowercasedPayload = payload.lowercased()

        XCTAssertTrue(lowercasedPayload.contains("observations"))
        XCTAssertTrue(lowercasedPayload.contains("evidence"))
        XCTAssertTrue(lowercasedPayload.contains("relationships"))
        XCTAssertTrue(lowercasedPayload.contains("watersupplyobservations"))
        XCTAssertTrue(lowercasedPayload.contains("servicepointobservations"))
        XCTAssertNoForbiddenDecisionTerms(in: payload)
    }

    func testLifecycleReadinessSupportsCreateTwinMode() {
        XCTAssertTrue(CaptureMode.allCases.map(\.rawValue).contains("create"))
    }

    func testLifecycleReadinessSupportsVerifyTwinMode() {
        XCTAssertTrue(CaptureMode.allCases.map(\.rawValue).contains("verify"))
    }

    func testLifecycleReadinessSupportsUpdateTwinMode() {
        XCTAssertTrue(CaptureMode.allCases.map(\.rawValue).contains("update"))
    }

    private func scanSourceFiles(terms: [String]) throws -> [String] {
        let fileURL = URL(fileURLWithPath: #filePath)
        let repositoryRoot = fileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let scanRoots = [
            repositoryRoot.appendingPathComponent("DaedalusContracts/Sources"),
            repositoryRoot.appendingPathComponent("DaedalusScan")
        ]

        let lowercasedTerms = terms.map { $0.lowercased() }
        var findings: [String] = []
        let fileManager = FileManager.default

        for root in scanRoots {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: nil
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
                let contents = try String(contentsOf: fileURL, encoding: .utf8)
                let relativePath = fileURL.path.replacingOccurrences(of: repositoryRoot.path + "/", with: "")
                for (lineIndex, line) in contents.components(separatedBy: .newlines).enumerated() {
                    let lowercasedLine = line.lowercased()
                    for term in lowercasedTerms where lowercasedLine.contains(term) {
                        findings.append("\(relativePath):\(lineIndex + 1): \(term)")
                    }
                }
            }
        }

        return findings.sorted()
    }

    private func encodedPayload<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        return try XCTUnwrap(String(data: data, encoding: .utf8))
    }

    private func XCTAssertNoForbiddenDecisionTerms(
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
