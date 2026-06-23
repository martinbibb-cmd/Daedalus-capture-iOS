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
        package.observations[1].evidenceRefs = ["missing-evidence"]

        let issues = validateEvidenceReferences(package)
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].path, "observations[1].evidenceRefs[0]")
        XCTAssertEqual(issues[0].code, "evidence.reference.missing")
    }

    func testDaedalusPackageValidationFailsWhenObservationIDsAreDuplicated() {
        var package = samplePackage()
        package.observations.append(package.observations[0])

        let issues = validateTwinIntegrity(package)
        XCTAssertTrue(issues.contains { $0.code == "observation.id.duplicate" })
    }

    func testDaedalusPackageValidationFailsWhenRelationshipEndpointIsMissing() {
        var package = samplePackage()
        package.relationships[0].to = "missing-target"

        let issues = validateTwinIntegrity(package)
        XCTAssertTrue(issues.contains { $0.code == "relationship.endpoint.missing" })
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
        XCTAssertEqual(package.packageVersion, 4)
        XCTAssertEqual(package.visitID, visit.id)
        XCTAssertEqual(package.propertyRef, "VIS-DAEDALUS-001")
        XCTAssertEqual(package.propertyIdentity.reference, "VIS-DAEDALUS-001")
        XCTAssertEqual(package.workingTwin?.propertyID, package.propertyIdentity.id)
        XCTAssertEqual(package.workingTwin?.repositoryState, .localWorkingCopy)
        XCTAssertEqual(package.surveyCaptureSession?.propertyID, package.propertyIdentity.id)
        XCTAssertEqual(package.surveyCaptureSession?.workingTwinID, package.workingTwin?.id)
        XCTAssertEqual(package.evidence.map(\.evidenceRef), [evidenceID.uuidString])
        XCTAssertEqual(package.evidence.first?.propertyID, package.propertyIdentity.propertyID)
        XCTAssertEqual(package.evidence.first?.twinRef, package.workingTwin?.twinRef)
        XCTAssertEqual(package.evidence.first?.sessionRef, package.surveyCaptureSession?.sessionRef)
        XCTAssertEqual(package.evidence.first?.mediaRef, "boiler-photo.jpg")
        XCTAssertEqual(package.evidence.first?.mediaType, .photo)
        XCTAssertEqual(package.observations.map(\.tag), ["area", "boiler", "photo evidence", "surveyor note"])
        XCTAssertEqual(package.observations[0].name, "Airing Cupboard")
        XCTAssertEqual(package.observations[0].confidence, .approximate)
        XCTAssertEqual(package.observations[1].observationID, component.id.uuidString)
        XCTAssertEqual(package.observations[1].tag, "boiler")
        XCTAssertEqual(package.observations[1].type, SystemComponentSubtype.unknownHeatSource.rawValue)
        XCTAssertEqual(package.observations[1].captureState, .roomAttached)
        XCTAssertEqual(package.observations[1].evidenceRefs, [evidenceID.uuidString])
        XCTAssertEqual(package.observations[2].observationID, evidenceID.uuidString)
        XCTAssertEqual(package.observations[2].assetRef, component.id.uuidString)
        XCTAssertEqual(package.relationships.count, 1)
        XCTAssertEqual(package.relationships[0].type, .containedIn)
        XCTAssertEqual(package.relationships[0].from, component.id.uuidString)
        XCTAssertEqual(package.relationships[0].to, room.id.uuidString)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(package)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(json.contains(#""packageVersion":4"#))
        XCTAssertTrue(json.contains(#""propertyIdentity""#))
        XCTAssertTrue(json.contains(#""workingTwin""#))
        XCTAssertTrue(json.contains(#""surveyCaptureSession""#))
        XCTAssertTrue(json.contains(#""property_id""#))
        XCTAssertTrue(json.contains(#""binary_embedded":false"#))
        XCTAssertTrue(json.contains(#""authoritative_truth":false"#))
        XCTAssertTrue(json.contains(#""observations""#))
        XCTAssertTrue(json.contains(#""relationship_id""#))
        XCTAssertTrue(json.contains(#""captured_by""#))
        ["recommendation", "simulation", "price", "score", "suitability"].forEach {
            XCTAssertFalse(json.contains($0))
        }
    }

    func testSharedHeatingSurveyFixtureValidates() throws {
        let fixture = try loadSharedHeatingSurveyFixture()
        let validation = validateDaedalusPackage(fixture)

        XCTAssertTrue(validation.valid)
        XCTAssertEqual(fixture.packageVersion, 3)
        XCTAssertEqual(fixture.propertyRef, "DAE-SMOKE-HEATING-001")
        XCTAssertEqual(fixture.observations.filter { $0.tag == "area" }.map(\.name), ["Kitchen", "Airing Cupboard", "Hall"])
        XCTAssertEqual(fixture.observations.filter { $0.tag == "radiator" }.count, 3)
        XCTAssertEqual(Set(fixture.relationships.map(\.type)), [.containedIn, .connectedTo, .controls])
        XCTAssertTrue(fixture.observations.contains { $0.confidence == .observed })
        XCTAssertTrue(fixture.observations.contains { $0.confidence == .approximate })
        XCTAssertTrue(fixture.observations.contains { $0.confidence == .unknown })
        XCTAssertEqual(fixture.waterSupplyObservations.map(\.id), [
            "water-flow-cup-kitchen",
            "water-pressure-flow-pairs",
            "water-flow-cup-bath",
            "water-customer-report",
            "water-not-tested",
        ])
        XCTAssertTrue(fixture.waterSupplyObservations.contains { $0.method == .customerReported && $0.confidence == .unknown })
        XCTAssertTrue(fixture.waterSupplyObservations.contains { $0.method == .notTested && $0.absenceReason == .noSuitableOutlet })
        XCTAssertEqual(fixture.servicePointObservations.count, 1)
        XCTAssertEqual(fixture.servicePointObservations[0].servicePointType, .bathTap)
        XCTAssertEqual(fixture.servicePointObservations[0].supplyType, .gravityHot)
        XCTAssertEqual(fixture.servicePointObservations[0].intendedPressureType, .mainsPressure)
        XCTAssertEqual(fixture.servicePointObservations[0].observedIssues, [.poorFlow, .mismatchSuspected])
    }

    func testCaptureExportShapeMatchesSharedHeatingSurveyExpectations() throws {
        let fixture = try loadSharedHeatingSurveyFixture()
        let visit = heatingSurveyVisit()

        let package = DaedalusPackageExporter.makePackage(
            from: visit,
            packageID: UUID(uuidString: "00000000-0000-0000-0000-00000000D003")!,
            createdAt: try XCTUnwrap(Self.isoDate("2026-06-07T09:30:00Z"))
        )
        let validation = validateDaedalusPackage(package)

        XCTAssertTrue(validation.valid)
        XCTAssertEqual(fixture.packageVersion, 3)
        XCTAssertEqual(package.packageVersion, 4)
        XCTAssertEqual(package.propertyRef, fixture.propertyRef)
        XCTAssertEqual(package.propertyIdentity.reference, fixture.propertyRef)
        XCTAssertEqual(package.workingTwin?.propertyID, package.propertyIdentity.id)
        XCTAssertEqual(package.surveyCaptureSession?.workingTwinID, package.workingTwin?.id)
        XCTAssertEqual(package.evidence.count, 3)
        XCTAssertTrue(package.evidence.allSatisfy { $0.propertyRef == fixture.propertyRef })
        XCTAssertTrue(package.evidence.allSatisfy { $0.binaryEmbedded == false })
        XCTAssertEqual(package.observations.filter { $0.tag == "area" }.compactMap(\.name), ["Kitchen", "Airing Cupboard", "Hall"])
        XCTAssertEqual(package.observations.filter { $0.tag == "boiler" }.count, 1)
        XCTAssertEqual(package.observations.filter { $0.tag == "cylinder" }.count, 1)
        XCTAssertEqual(package.observations.filter { $0.tag == "controls" }.count, 1)
        XCTAssertEqual(package.observations.filter { $0.tag == "radiator" }.count, 3)
        XCTAssertEqual(package.observations.filter { $0.tag.contains("evidence") }.count, 3)
        XCTAssertEqual(package.waterSupplyObservations.count, 5)
        XCTAssertEqual(package.waterSupplyObservations.first?.method, .flowCup)
        XCTAssertTrue(package.waterSupplyObservations.contains { $0.method == .pressureFlowTestKit })
        XCTAssertTrue(package.waterSupplyObservations.contains { $0.id == "water-flow-cup-bath" && $0.location == .bathTap })
        XCTAssertTrue(package.waterSupplyObservations.contains { $0.method == .notTested && $0.absenceReason != nil })
        XCTAssertEqual(package.servicePointObservations.count, 1)
        XCTAssertEqual(package.servicePointObservations[0].servicePointType, .bathTap)
        XCTAssertEqual(package.servicePointObservations[0].areaID, "00000000-0000-0000-0000-000000000102")
        XCTAssertEqual(package.servicePointObservations[0].servedByAssetIDs, ["00000000-0000-0000-0000-000000000302"])
        XCTAssertEqual(package.servicePointObservations[0].evidenceIDs, ["00000000-0000-0000-0000-000000000202"])
        XCTAssertEqual(package.relationships.map(\.type), fixture.relationships.map(\.type))
        XCTAssertTrue(package.observations.contains { $0.confidence == .observed })
        XCTAssertTrue(package.observations.contains { $0.confidence == .approximate })
        XCTAssertTrue(package.observations.contains { $0.confidence == .unknown })
        XCTAssertTrue(package.relationships.allSatisfy { !$0.from.isEmpty && !$0.to.isEmpty })

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let json = try XCTUnwrap(String(data: try encoder.encode(package), encoding: .utf8))
        XCTAssertTrue(json.contains(#""packageVersion":4"#))
        XCTAssertTrue(json.contains(#""propertyIdentity""#))
        XCTAssertTrue(json.contains(#""evidence_ref""#))
        XCTAssertTrue(json.contains(#""media_ref""#))
        XCTAssertTrue(json.contains(#""observations""#))
        XCTAssertTrue(json.contains(#""relationships""#))
        XCTAssertTrue(json.contains(#""evidence_refs""#))
        XCTAssertFalse(json.localizedCaseInsensitiveContains("recommendation"))
    }

    func testWaterSupplyValidationRejectsMissingEvidenceReference() {
        var package = samplePackage()
        package.waterSupplyObservations = [
            waterObservation(evidenceIDs: ["missing-evidence"])
        ]

        let issues = validateTwinIntegrity(package)

        XCTAssertTrue(issues.contains { $0.code == "waterSupply.evidence.reference.missing" })
    }

    func testWaterSupplyValidationRejectsNumericValueWithoutUnit() {
        var package = samplePackage()
        package.waterSupplyObservations = [
            waterObservation(values: [
                WaterMeasurementValue(name: .flowRate, value: "16", confidence: .approximate)
            ])
        ]

        let issues = validateTwinIntegrity(package)

        XCTAssertTrue(issues.contains { $0.code == "waterSupply.value.unitMissing" })
    }

    func testWaterSupplyValidationRequiresNotTestedReason() {
        var package = samplePackage()
        package.waterSupplyObservations = [
            waterObservation(method: .notTested, intent: .notTested, values: [], absenceReason: nil, confidence: .unknown, notes: nil)
        ]

        let issues = validateTwinIntegrity(package)

        XCTAssertTrue(issues.contains { $0.code == "waterSupply.notTested.reasonMissing" })
    }

    func testServicePointValidationRejectsMissingAreaReference() {
        var package = samplePackage()
        package.servicePointObservations = [
            servicePointObservation(areaID: "missing-area")
        ]

        let issues = validateTwinIntegrity(package)

        XCTAssertTrue(issues.contains { $0.code == "servicePoint.area.reference.missing" })
    }

    func testServicePointValidationRejectsMissingAssetAndEvidenceReferences() {
        var package = samplePackage()
        package.servicePointObservations = [
            servicePointObservation(servedByAssetIDs: ["missing-cylinder"], evidenceIDs: ["missing-evidence"])
        ]

        let issues = validateTwinIntegrity(package)

        XCTAssertTrue(issues.contains { $0.code == "servicePoint.servedByAsset.reference.missing" })
        XCTAssertTrue(issues.contains { $0.code == "servicePoint.evidence.reference.missing" })
    }

    private func samplePackage() -> DaedalusPackage {
        let createdAt = Date(timeIntervalSince1970: 1_704_067_200)
        let evidenceID = UUID(uuidString: "00000000-0000-0000-0000-000000000090")!

        return DaedalusPackage(
            packageID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            visitID: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            propertyRef: "VIS-DAEDALUS-001",
            createdAt: createdAt,
            observations: [
                DaedalusObservation(
                    observationID: "00000000-0000-0000-0000-000000000020",
                    tag: "area",
                    name: "Airing Cupboard",
                    confidence: .approximate,
                    provenance: TwinProvenance(
                        source: "Daedalus Capture",
                        observedAt: createdAt,
                        observedBy: "surveyor@example.com"
                    )
                ),
                DaedalusObservation(
                    observationID: "00000000-0000-0000-0000-000000000040",
                    tag: "boiler",
                    name: "Boiler",
                    evidenceRefs: [evidenceID.uuidString],
                    provenance: TwinProvenance(
                        source: "Daedalus Capture",
                        observedAt: createdAt,
                        observedBy: "surveyor@example.com"
                    )
                ),
                DaedalusObservation(
                    observationID: evidenceID.uuidString,
                    tag: "photo evidence",
                    fileRef: "boiler-photo.jpg",
                    confidence: .observed,
                    provenance: TwinProvenance(
                        source: "Daedalus Capture",
                        observedAt: createdAt,
                        observedBy: "surveyor@example.com"
                    ),
                )
            ],
            relationships: [
                DaedalusRelationship(
                    relationshipID: "rel-contained-in",
                    type: .containedIn,
                    from: "00000000-0000-0000-0000-000000000040",
                    to: "00000000-0000-0000-0000-000000000020",
                    provenance: TwinProvenance(
                        source: "Daedalus Capture",
                        observedAt: createdAt,
                        observedBy: "surveyor@example.com"
                    )
                )
            ]
        )
    }

    private func loadSharedHeatingSurveyFixture() throws -> DaedalusPackage {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "daedalus-package-v3-heating-survey",
            withExtension: "json"
        ))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DaedalusPackage.self, from: Data(contentsOf: url))
    }

    private func waterObservation(
        method: WaterSupplyMethod = .flowCup,
        intent: WaterSupplyIntent = .usableHouseholdCapacity,
        values: [WaterMeasurementValue] = [
            WaterMeasurementValue(name: .flowRate, value: "16", unit: "l/min", confidence: .approximate)
        ],
        absenceReason: WaterAbsenceReason? = nil,
        confidence: Confidence = .approximate,
        evidenceIDs: [String] = ["00000000-0000-0000-0000-000000000090"],
        notes: String? = "Field observation only."
    ) -> WaterSupplyObservation {
        let createdAt = Date(timeIntervalSince1970: 1_704_067_200)
        return WaterSupplyObservation(
            id: "water-test-001",
            observedAt: createdAt,
            observedBy: "surveyor@example.com",
            method: method,
            location: method == .notTested ? .unknown : .kitchenColdTap,
            intent: intent,
            values: values,
            boundaryConditions: WaterBoundaryConditions(otherOutletsOpenDuringTest: .false),
            suspectedLimitations: method == .customerReported ? [.customerReportOnly] : [],
            absenceReason: absenceReason,
            confidence: confidence,
            evidenceIDs: evidenceIDs,
            provenance: TwinProvenance(
                source: "water-supply-test",
                observedAt: createdAt,
                observedBy: "surveyor@example.com"
            ),
            notes: notes
        )
    }

    private func servicePointObservation(
        areaID: String = "00000000-0000-0000-0000-000000000020",
        servedByAssetIDs: [String] = ["00000000-0000-0000-0000-000000000040"],
        evidenceIDs: [String] = ["00000000-0000-0000-0000-000000000090"]
    ) -> ServicePointObservation {
        let createdAt = Date(timeIntervalSince1970: 1_704_067_200)
        return ServicePointObservation(
            id: "service-point-bath-tap",
            areaID: areaID,
            servicePointType: .bathTap,
            supplyType: .gravityHot,
            intendedPressureType: .mainsPressure,
            servedByAssetIDs: servedByAssetIDs,
            observedIssues: [.poorFlow, .mismatchSuspected],
            evidenceIDs: evidenceIDs,
            confidence: .approximate,
            provenance: TwinProvenance(
                source: "service-point-capture",
                observedAt: createdAt,
                observedBy: "surveyor@example.com"
            ),
            notes: "Bath tap poor flow observed."
        )
    }

    private func heatingSurveyVisit() -> Visit {
        let kitchen = Room(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            name: "Kitchen",
            spatialPlacement: SpatialPlacement(captureState: .anchored, confidence: .high)
        )
        let airingCupboard = Room(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
            name: "Airing Cupboard",
            spatialPlacement: SpatialPlacement(captureState: .anchored, confidence: .high)
        )
        let hall = Room(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!,
            name: "Hall",
            spatialPlacement: SpatialPlacement(captureState: .anchored, confidence: .high)
        )
        let boilerEvidence = Evidence(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
            kind: .photo,
            localFileName: "boiler-kitchen.jpg",
            createdAt: Self.isoDate("2026-06-07T09:32:30Z")!
        )
        let cylinderEvidence = Evidence(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
            kind: .photo,
            localFileName: "cylinder-airing-cupboard.jpg",
            createdAt: Self.isoDate("2026-06-07T09:35:30Z")!
        )
        let thermostatEvidence = Evidence(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000203")!,
            kind: .textNote,
            localFileName: "thermostat-note.txt",
            createdAt: Self.isoDate("2026-06-07T09:39:30Z")!
        )
        let boiler = SystemComponent(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000301")!,
            kind: .boiler,
            name: "System boiler",
            componentAttributes: ["location": kitchen.id.uuidString],
            evidence: [boilerEvidence],
            spatialPlacement: SpatialPlacement(captureState: .areaReferenceOnly, confidence: .medium)
        )
        let cylinder = SystemComponent(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000302")!,
            kind: .cylinder,
            name: "Unvented cylinder",
            componentAttributes: ["location": airingCupboard.id.uuidString],
            evidence: [cylinderEvidence],
            spatialPlacement: SpatialPlacement(captureState: .areaReferenceOnly, confidence: .medium)
        )
        let thermostat = SystemComponent(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000303")!,
            kind: .controls,
            name: "Room thermostat",
            componentAttributes: ["location": hall.id.uuidString],
            evidence: [thermostatEvidence],
            spatialPlacement: SpatialPlacement(captureState: .areaReferenceOnly, confidence: .medium)
        )
        let kitchenRadiator = SystemComponent(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000401")!,
            kind: .radiator,
            name: "Kitchen radiator",
            componentAttributes: ["location": kitchen.id.uuidString],
            spatialPlacement: SpatialPlacement(captureState: .areaReferenceOnly, confidence: .medium)
        )
        let hallRadiator = SystemComponent(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000402")!,
            kind: .radiator,
            name: "Hall radiator",
            componentAttributes: ["location": hall.id.uuidString],
            spatialPlacement: SpatialPlacement(captureState: .approximate, confidence: .low)
        )
        let livingRoomRadiator = SystemComponent(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000403")!,
            kind: .radiator,
            name: "Living room radiator",
            spatialPlacement: SpatialPlacement(captureState: .failed, confidence: .unknown)
        )

        let waterObservations = [
            WaterSupplyObservation(
                id: "water-flow-cup-kitchen",
                observedAt: Self.isoDate("2026-06-07T09:46:00Z")!,
                observedBy: "engineer-001",
                method: .flowCup,
                location: .kitchenColdTap,
                intent: .usableHouseholdCapacity,
                instrument: "calibrated flow cup",
                values: [WaterMeasurementValue(name: .flowRate, value: "16", unit: "l/min", confidence: .approximate)],
                boundaryConditions: WaterBoundaryConditions(otherOutletsOpenDuringTest: .false),
                suspectedLimitations: [.restrictedOutlet],
                confidence: .approximate,
                evidenceIDs: [thermostatEvidence.id.uuidString],
                provenance: TwinProvenance(source: "water-supply-test", observedAt: Self.isoDate("2026-06-07T09:46:00Z")!, observedBy: "engineer-001"),
                notes: "Kitchen cold tap flow cup observation only."
            ),
            WaterSupplyObservation(
                id: "water-pressure-flow-pairs",
                observedAt: Self.isoDate("2026-06-07T09:48:00Z")!,
                observedBy: "engineer-001",
                method: .pressureFlowTestKit,
                location: .outsideTap,
                intent: .incomingMainCapacity,
                values: [
                    WaterMeasurementValue(name: .flowAtPressure, value: "16", unit: "l/min", condition: "0 bar residual pressure", confidence: .observed),
                    WaterMeasurementValue(name: .flowAtPressure, value: "14", unit: "l/min", condition: "1 bar residual pressure", confidence: .observed)
                ],
                boundaryConditions: WaterBoundaryConditions(otherOutletsOpenDuringTest: .false, restrictorOrAeratorSuspected: .false),
                confidence: .observed,
                evidenceIDs: [thermostatEvidence.id.uuidString],
                provenance: TwinProvenance(source: "water-supply-test", observedAt: Self.isoDate("2026-06-07T09:48:00Z")!, observedBy: "engineer-001")
            ),
            WaterSupplyObservation(
                id: "water-flow-cup-bath",
                observedAt: Self.isoDate("2026-06-07T09:47:00Z")!,
                observedBy: "engineer-001",
                method: .flowCup,
                location: .bathTap,
                intent: .servicePointExperience,
                instrument: "calibrated flow cup",
                values: [WaterMeasurementValue(name: .flowRate, value: "5", unit: "l/min", confidence: .approximate)],
                boundaryConditions: WaterBoundaryConditions(otherOutletsOpenDuringTest: .false),
                suspectedLimitations: [.restrictedOutlet],
                confidence: .approximate,
                evidenceIDs: [cylinderEvidence.id.uuidString],
                provenance: TwinProvenance(source: "water-supply-test", observedAt: Self.isoDate("2026-06-07T09:47:00Z")!, observedBy: "engineer-001"),
                notes: "Bath tap flow cup observation at the customer service point."
            ),
            WaterSupplyObservation(
                id: "water-customer-report",
                observedAt: Self.isoDate("2026-06-07T09:50:00Z")!,
                observedBy: "engineer-001",
                method: .customerReported,
                location: .showerOutlet,
                intent: .customerComplaintContext,
                values: [
                    WaterMeasurementValue(name: .qualitativeObservation, value: "Shower slows when kitchen cold tap runs.", confidence: .unknown)
                ],
                suspectedLimitations: [.customerReportOnly],
                confidence: .unknown,
                evidenceIDs: [thermostatEvidence.id.uuidString],
                provenance: TwinProvenance(source: "customer-report", observedAt: Self.isoDate("2026-06-07T09:50:00Z")!, observedBy: "engineer-001")
            ),
            WaterSupplyObservation(
                id: "water-not-tested",
                observedAt: Self.isoDate("2026-06-07T09:51:00Z")!,
                observedBy: "engineer-001",
                method: .notTested,
                location: .unknown,
                intent: .notTested,
                suspectedLimitations: [.noSuitableOutlet],
                absenceReason: .noSuitableOutlet,
                confidence: .unknown,
                provenance: TwinProvenance(source: "water-supply-test", observedAt: Self.isoDate("2026-06-07T09:51:00Z")!, observedBy: "engineer-001"),
                notes: "No safe full-flow test point found."
            )
        ]
        let servicePointObservations = [
            ServicePointObservation(
                id: "service-point-bath-tap",
                areaID: airingCupboard.id.uuidString,
                servicePointType: .bathTap,
                supplyType: .gravityHot,
                intendedPressureType: .mainsPressure,
                servedByAssetIDs: [cylinder.id.uuidString],
                observedIssues: [.poorFlow, .mismatchSuspected],
                evidenceIDs: [cylinderEvidence.id.uuidString],
                confidence: .approximate,
                provenance: TwinProvenance(source: "service-point-capture", observedAt: Self.isoDate("2026-06-07T09:52:00Z")!, observedBy: "engineer-001"),
                notes: "Bath tap appears intended for mains pressure but is served by open vented/gravity hot supply; poor flow observed."
            )
        ]

        return Visit(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000DAED")!,
            reference: "DAE-SMOKE-HEATING-001",
            createdAt: Self.isoDate("2026-06-07T09:30:00Z")!,
            twinKind: .system,
            engineerName: "engineer-001",
            rooms: [kitchen, airingCupboard, hall],
            relationships: [
                SpatialRelationship(sourceComponentID: boiler.id, relationship: .containedIn, targetAreaID: kitchen.id),
                SpatialRelationship(sourceComponentID: cylinder.id, relationship: .containedIn, targetAreaID: airingCupboard.id),
                SpatialRelationship(sourceComponentID: thermostat.id, relationship: .containedIn, targetAreaID: hall.id),
                SpatialRelationship(sourceComponentID: boiler.id, relationship: .connectedTo, targetComponentID: cylinder.id),
                SpatialRelationship(sourceComponentID: thermostat.id, relationship: .controls, targetComponentID: kitchenRadiator.id),
                SpatialRelationship(sourceComponentID: thermostat.id, relationship: .controls, targetComponentID: hallRadiator.id),
                SpatialRelationship(sourceComponentID: thermostat.id, relationship: .controls, targetComponentID: livingRoomRadiator.id)
            ],
            components: [boiler, cylinder, thermostat, kitchenRadiator, hallRadiator, livingRoomRadiator],
            waterSupplyObservations: waterObservations,
            servicePointObservations: servicePointObservations
        )
    }

    private static func isoDate(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }
}
