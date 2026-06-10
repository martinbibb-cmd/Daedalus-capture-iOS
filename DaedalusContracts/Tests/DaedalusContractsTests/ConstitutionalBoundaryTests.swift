import XCTest
@testable import DaedalusContracts

final class ConstitutionalBoundaryTests: XCTestCase {
    func testObservationBoundaryDoesNotExposeProposedOrRecommendationWorkflowLanguage() throws {
        let findings = scanSourceFiles(
            terms: [
                "proposedSystem",
                "proposed system",
                "recommendedSystem",
                "recommended system",
                "best option",
                "suitability",
                "ranking"
            ]
        )

        XCTAssertEqual(findings, [], "Capture workflow language should be Create/Verify/Update and observation-only. Findings: \(findings.joined(separator: "\n"))")
    }

    func testCaptureExportContainsObservationsEvidenceMeasurementsAndRelationshipsButNoDecisionOutputs() throws {
        let evidence = Evidence(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000090")!,
            kind: .photo,
            localFileName: "plant-room.jpg"
        )
        let area = Room(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000020")!,
            name: "Plant Room",
            evidence: [evidence]
        )
        let component = SystemComponent(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000040")!,
            kind: .boiler,
            name: "Observed appliance",
            evidence: [evidence]
        )
        let visit = Visit(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            reference: "PR-1-CAPTURE",
            twinKind: .system,
            rooms: [area],
            relationships: [
                SpatialRelationship(
                    sourceComponentID: component.id,
                    relationship: .containedIn,
                    targetAreaID: area.id
                )
            ],
            components: [component],
            waterSupplyObservations: [
                WaterSupplyObservation(
                    id: "water-observation-1",
                    observedBy: "Daedalus Scan",
                    method: .flowCup,
                    location: .kitchenColdTap,
                    intent: .usableHouseholdCapacity,
                    values: [
                        WaterMeasurementValue(name: .flowRate, value: "12", unit: "l/min", confidence: .observed)
                    ],
                    confidence: .observed,
                    evidenceIDs: [evidence.id.uuidString],
                    provenance: TwinProvenance(source: "capture-boundary-test", observedBy: "Daedalus Scan")
                )
            ],
            servicePointObservations: [
                ServicePointObservation(
                    id: "service-point-1",
                    areaID: area.id.uuidString,
                    servicePointType: .kitchenTap,
                    confidence: .observed,
                    provenance: TwinProvenance(source: "capture-boundary-test", observedBy: "Daedalus Scan")
                )
            ]
        )

        let package = DaedalusPackageExporter.makePackage(from: visit, source: "Daedalus Scan")
        let encoded = try JSONEncoder().encode(package)
        let payload = String(decoding: encoded, as: UTF8.self)

        XCTAssertFalse(package.observations.isEmpty)
        XCTAssertTrue(package.observations.contains { $0.tag.contains("evidence") })
        XCTAssertFalse(package.relationships.isEmpty)
        XCTAssertFalse(package.waterSupplyObservations.isEmpty)
        XCTAssertFalse(package.servicePointObservations.isEmpty)
        XCTAssertNoForbiddenDecisionTerms(payload)
    }

    func testLifecycleReadinessSupportsCreateTwinMode() {
        XCTAssertTrue(
            CaptureMode.allCases.map(\.rawValue).contains("create"),
            "Capture must grow from current/proposed survey mode into Create Twin."
        )
    }

    func testLifecycleReadinessSupportsVerifyTwinMode() {
        XCTAssertTrue(
            CaptureMode.allCases.map(\.rawValue).contains("verify"),
            "Capture must support Verify Twin visits without assuming every visit is a blank survey."
        )
    }

    func testLifecycleReadinessSupportsUpdateTwinMode() {
        XCTAssertTrue(
            CaptureMode.allCases.map(\.rawValue).contains("update"),
            "Capture must support Update Twin visits where only changed reality is amended."
        )
    }

    private func scanSourceFiles(terms: [String]) throws -> [String] {
        let root = repositoryRoot()
        let scanRoots = [
            root.appendingPathComponent("DaedalusContracts/Sources"),
            root.appendingPathComponent("DaedalusScan")
        ]
        let normalizedTerms = terms.map { ($0, $0.lowercased()) }
        var findings: [String] = []

        for scanRoot in scanRoots {
            guard let enumerator = FileManager.default.enumerator(
                at: scanRoot,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
                let contents = try String(contentsOf: fileURL)
                let relativePath = fileURL.path.replacingOccurrences(of: root.path + "/", with: "")
                for (lineIndex, line) in contents.components(separatedBy: .newlines).enumerated() {
                    let normalizedLine = line.lowercased()
                    for term in normalizedTerms where normalizedLine.contains(term.1) {
                        findings.append("\(relativePath):\(lineIndex + 1): \(term.0): \(line.trimmingCharacters(in: .whitespaces))")
                    }
                }
            }
        }

        return findings
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func XCTAssertNoForbiddenDecisionTerms(_ payload: String, file: StaticString = #filePath, line: UInt = #line) {
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
        let normalizedPayload = payload.lowercased()
        let findings = forbiddenTerms.filter { normalizedPayload.contains($0.lowercased()) }

        XCTAssertEqual(findings, [], "Capture export should not produce decision outputs.", file: file, line: line)
    }
}
