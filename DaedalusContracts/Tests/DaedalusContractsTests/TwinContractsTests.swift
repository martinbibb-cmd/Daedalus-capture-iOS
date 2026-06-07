import XCTest
@testable import DaedalusContracts

final class TwinContractsTests: XCTestCase {
    func testDaedalusPackageValidationPassesForValidSample() {
        let result = validateDaedalusPackage(samplePackage())
        XCTAssertTrue(result.valid)
        XCTAssertEqual(result.issues, [])
    }

    func testDaedalusPackageValidationFailsWhenEvidenceReferenceIsMissing() {
        var package = samplePackage()
        package.systemTwin.assets[0].evidenceIDs = [UUID(uuidString: "00000000-0000-0000-0000-000000000999")!]

        let issues = validateEvidenceReferences(package)
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].path, "systemTwin.assets[0].evidenceIDs[0]")
        XCTAssertEqual(issues[0].code, "evidence.reference.missing")
    }

    func testDaedalusPackageValidationFailsWhenAssetIDsAreDuplicated() {
        var package = samplePackage()
        package.systemTwin.assets = [
            package.systemTwin.assets[0],
            SystemAsset(
                id: package.systemTwin.assets[0].id,
                assetType: .cylinder,
                placement: TwinSpatialPlacement(confidence: .observed, captureState: .roomAttached),
                confidence: .observed,
                evidenceIDs: []
            )
        ]

        let issues = validateTwinIntegrity(package)
        XCTAssertTrue(issues.contains { $0.code == "systemAsset.id.duplicate" })
    }

    func testDaedalusPackageValidationFailsWhenEvidenceIDsAreDuplicated() {
        var package = samplePackage()
        package.evidence.append(
            TwinEvidence(
                id: package.evidence[0].id,
                title: "Duplicate",
                provenance: TwinProvenance(source: "Daedalus Scan"),
                confidence: .observed
            )
        )

        let issues = validateTwinIntegrity(package)
        XCTAssertTrue(issues.contains { $0.code == "twinEvidence.id.duplicate" })
    }

    func testVisitExportsToMinimumValidDaedalusPackage() throws {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let evidenceID = UUID(uuidString: "00000000-0000-0000-0000-000000000090")!
        let room = Room(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000020")!,
            name: "Airing Cupboard",
            spatialPlacement: SpatialPlacement(captureState: .approximate, confidence: .low)
        )
        let component = SystemComponent(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000040")!,
            kind: .boiler,
            evidence: [
                Evidence(
                    id: evidenceID,
                    kind: .photo,
                    localFileName: "boiler-photo.jpg",
                    createdAt: createdAt
                )
            ],
            spatialPlacement: SpatialPlacement(captureState: .areaReferenceOnly, confidence: .low)
        )
        let visit = Visit(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
            reference: "VIS-DAEDALUS-001",
            createdAt: createdAt,
            twinKind: .system,
            customerName: "Family of four",
            notes: "Captured visit",
            rooms: [room],
            relationships: [
                SpatialRelationship(
                    sourceComponentID: component.id,
                    relationship: .containedIn,
                    targetAreaID: room.id
                )
            ],
            components: [component]
        )

        let package = DaedalusPackageExporter.makePackage(
            from: visit,
            packageID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            createdAt: createdAt
        )

        let validation = validateDaedalusPackage(package)
        XCTAssertTrue(validation.valid)
        XCTAssertEqual(package.version, "1.0.0")
        XCTAssertEqual(package.houseTwin.areas.map(\.name), ["Airing Cupboard"])
        XCTAssertEqual(package.houseTwin.areas[0].placement.captureState, .approximate)
        XCTAssertEqual(package.houseTwin.areas[0].confidence, .approximate)
        XCTAssertEqual(package.systemTwin.assets.count, 1)
        XCTAssertEqual(package.systemTwin.assets[0].assetType, .boiler)
        XCTAssertEqual(package.systemTwin.assets[0].canonicalCategory, SystemComponentCategory.heatSource.rawValue)
        XCTAssertEqual(package.systemTwin.assets[0].canonicalSubtype, SystemComponentSubtype.unknownHeatSource.rawValue)
        XCTAssertEqual(package.systemTwin.assets[0].placement.captureState, .roomAttached)
        XCTAssertEqual(package.systemTwin.assets[0].evidenceIDs, [evidenceID])
        XCTAssertEqual(package.systemTwin.relationships.count, 1)
        XCTAssertEqual(package.systemTwin.relationships[0].relationship, .containedIn)
        XCTAssertEqual(package.systemTwin.relationships[0].targetAreaID, room.id)
        XCTAssertEqual(package.evidence.map(\.id), [evidenceID])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(package)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        ["recommendation", "simulation", "price", "score", "suitability"].forEach {
            XCTAssertFalse(json.contains($0))
        }
    }

    private func samplePackage() -> DaedalusPackage {
        let createdAt = Date(timeIntervalSince1970: 1_704_067_200)
        let evidenceID = UUID(uuidString: "00000000-0000-0000-0000-000000000090")!

        return DaedalusPackage(
            packageID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            createdAt: createdAt,
            houseTwin: HouseTwin(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
                areas: [
                    SpatialArea(
                        id: UUID(uuidString: "00000000-0000-0000-0000-000000000020")!,
                        name: "Airing Cupboard",
                        placement: TwinSpatialPlacement(
                            confidence: .approximate,
                            captureState: .roomAttached
                        ),
                        confidence: .approximate
                    )
                ]
            ),
            systemTwin: SystemTwin(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000030")!,
                assets: [
                    SystemAsset(
                        id: UUID(uuidString: "00000000-0000-0000-0000-000000000040")!,
                        assetType: .boiler,
                        placement: TwinSpatialPlacement(
                            confidence: .observed,
                            captureState: .evidenceOnly
                        ),
                        confidence: .observed,
                        evidenceIDs: [evidenceID]
                    )
                ]
            ),
            homeTwin: HomeTwin(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000070")!,
                occupancyDescription: "Family of four"
            ),
            evidence: [
                TwinEvidence(
                    id: evidenceID,
                    title: "Boiler Photo",
                    description: "boiler-photo.jpg",
                    provenance: TwinProvenance(
                        source: "Daedalus Scan",
                        observedAt: createdAt,
                        observedBy: "surveyor@example.com"
                    ),
                    confidence: .observed
                )
            ]
        )
    }
}
