import XCTest
@testable import DaedalusContracts

final class SurveyModelsTests: XCTestCase {
    func testVisitIdentityFieldsRoundTrip() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let visit = Visit(
            reference: "VIS-ID-001",
            twinKind: .home,
            customerName: "Acme Estates",
            addressLine: "12 High Street",
            postcode: "SW1A 1AA",
            engineerName: "J. Smith",
            appointmentDate: date,
            notes: "Access via side gate."
        )
        let package = VisitPackage(visits: [visit])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(package)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(VisitPackage.self, from: data)

        let v = decoded.visits[0]
        XCTAssertEqual(v.customerName, "Acme Estates")
        XCTAssertEqual(v.addressLine, "12 High Street")
        XCTAssertEqual(v.postcode, "SW1A 1AA")
        XCTAssertEqual(v.engineerName, "J. Smith")
        XCTAssertEqual(v.appointmentDate, date)
        XCTAssertEqual(v.notes, "Access via side gate.")
    }

    func testVisitIdentityFieldsDefaultToEmptyOnLegacyDecode() throws {
        let json = "[{\"id\":\"00000000-0000-0000-0000-000000000099\",\"reference\":\"VIS-LEGACY-ID\",\"createdAt\":\"2024-01-01T00:00:00Z\",\"twinKind\":\"home\",\"rooms\":[],\"components\":[]}]"
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let visits = try decoder.decode([Visit].self, from: Data(json.utf8))
        let v = visits[0]
        XCTAssertEqual(v.customerName, "")
        XCTAssertEqual(v.addressLine, "")
        XCTAssertEqual(v.postcode, "")
        XCTAssertNil(v.engineerName)
        XCTAssertNil(v.appointmentDate)
        XCTAssertEqual(v.notes, "")
    }

    func testVisitIdentityFieldsOptionalEngineerAndDateNilByDefault() throws {
        let visit = Visit(reference: "VIS-OPT", twinKind: .system)
        let package = VisitPackage(visits: [visit])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(package)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(VisitPackage.self, from: data)

        XCTAssertNil(decoded.visits[0].engineerName)
        XCTAssertNil(decoded.visits[0].appointmentDate)
    }

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
            ],
            spatialPlacement: SpatialPlacement(
                anchorID: "anchor-flue-1",
                approximatePosition: SpatialPosition(x: 1.2, y: 0.6, z: -0.4),
                captureState: .anchored,
                confidence: .high
            )
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
        XCTAssertEqual(decoded.visits[0].components[0].spatialPlacement.anchorID, "anchor-flue-1")
        XCTAssertEqual(decoded.visits[0].components[0].spatialPlacement.captureState, .anchored)
        XCTAssertEqual(decoded.visits[0].components[0].spatialPlacement.confidence, .high)
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
            ],
            spatialPlacement: SpatialPlacement(
                approximatePosition: SpatialPosition(x: 0.0, y: 0.0, z: 0.0),
                captureState: .approximate,
                confidence: .medium
            )
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
            ],
            spatialPlacement: SpatialPlacement(
                anchorID: "boiler-anchor",
                approximatePosition: SpatialPosition(x: 2.4, y: 1.1, z: -0.8),
                captureState: .areaReferenceOnly,
                confidence: .low
            )
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
        XCTAssertEqual(decoded.visits[0].rooms[0].spatialPlacement.captureState, .approximate)
        XCTAssertEqual(decoded.visits[0].rooms[0].spatialPlacement.confidence, .medium)
        XCTAssertEqual(decoded.visits[0].rooms[0].survey["heating.emitters.present"]?.reviewStatus, .needsReview)
        XCTAssertEqual(decoded.visits[0].rooms[0].survey["heating.emitters.present"]?.reviewNotes, "Double-check emitter count.")
        XCTAssertEqual(decoded.visits[0].rooms[0].survey["ventilation.extract.count"]?.numericValue, 2)
        XCTAssertEqual(decoded.visits[0].components.count, 1)
        XCTAssertEqual(decoded.visits[0].components[0].kind, .boiler)
        XCTAssertEqual(decoded.visits[0].components[0].notes, "Observed in utility area.")
        XCTAssertEqual(decoded.visits[0].components[0].reviewStatus, .confirmed)
        XCTAssertEqual(decoded.visits[0].components[0].reviewNotes, "Visual checks complete.")
        XCTAssertEqual(decoded.visits[0].components[0].spatialPlacement.captureState, .areaReferenceOnly)
        XCTAssertEqual(decoded.visits[0].components[0].spatialPlacement.anchorID, "boiler-anchor")
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
        XCTAssertEqual(decoded.metadata?.schemaVersion, 3)
        XCTAssertEqual(decoded.metadata?.source, "Daedalus Capture")
        XCTAssertEqual(decoded.metadata?.exportedByApp, "Daedalus Capture")
        XCTAssertEqual(decoded.schemaVersion, 3)
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

    func testVisitPackageRoundTripPreservesWaterTestsAndServicePointCounts() throws {
        let createdAt = Date(timeIntervalSince1970: 1_704_067_200)
        let areaID = "00000000-0000-0000-0000-000000000020"
        let assetID = "00000000-0000-0000-0000-000000000040"
        let evidenceID = "00000000-0000-0000-0000-000000000090"
        let visit = Visit(
            reference: "VIS-WATER-LEDGER",
            twinKind: .system,
            rooms: [
                Room(id: UUID(uuidString: areaID)!, name: "Bathroom")
            ],
            components: [
                SystemComponent(id: UUID(uuidString: assetID)!, kind: .cylinder)
            ],
            waterSupplyObservations: [
                WaterSupplyObservation(
                    id: "water-test-001",
                    observedAt: createdAt,
                    observedBy: "surveyor@example.com",
                    method: .flowCup,
                    location: .bathTap,
                    intent: .servicePointExperience,
                    values: [WaterMeasurementValue(name: .flowRate, value: "12", unit: "l/min")],
                    confidence: .approximate,
                    evidenceIDs: [evidenceID],
                    provenance: TwinProvenance(source: "water-supply-test", observedAt: createdAt, observedBy: "surveyor@example.com")
                )
            ],
            servicePointObservations: [
                ServicePointObservation(
                    id: "service-point-bath-tap",
                    areaID: areaID,
                    servicePointType: .bathTap,
                    supplyType: .mainsHot,
                    intendedPressureType: .mainsPressure,
                    servedByAssetIDs: [assetID],
                    evidenceIDs: [evidenceID],
                    confidence: .approximate,
                    provenance: TwinProvenance(source: "service-point-capture", observedAt: createdAt, observedBy: "surveyor@example.com")
                )
            ]
        )

        let encoded = try JSONEncoder.iso8601Encoded.encode(VisitPackage(visits: [visit]))
        let decoded = try JSONDecoder.iso8601Decoded.decode(VisitPackage.self, from: encoded)

        XCTAssertEqual(decoded.visits[0].waterSupplyObservations.count, 1)
        XCTAssertEqual(decoded.visits[0].servicePointObservations.count, 1)
        XCTAssertEqual(decoded.visits[0].waterSupplyObservations[0].id, "water-test-001")
        XCTAssertEqual(decoded.visits[0].servicePointObservations[0].id, "service-point-bath-tap")
    }

    func testSectionStatusDecodesFromLegacyVisitWithNoSectionStatuses() throws {
        // Simulate a Visit encoded without sectionStatuses (legacy format)
        let json = "[{\"id\":\"00000000-0000-0000-0000-000000000001\",\"reference\":\"VIS-LEGACY\",\"createdAt\":\"2024-01-01T00:00:00Z\",\"twinKind\":\"system\",\"rooms\":[],\"components\":[]}]"
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let visits = try decoder.decode([Visit].self, from: Data(json.utf8))
        XCTAssertEqual(visits[0].sectionStatuses, [:])
    }

    func testCaptureModeUsesTwinLifecycleLanguage() {
        XCTAssertEqual(CaptureMode.allCases, [.create, .verify, .update])
        XCTAssertEqual(CaptureMode.allCases.map(\.title), ["Create Twin", "Verify Twin", "Update Twin"])
    }

    func testCaptureModeDecodesLegacySurveyValues() throws {
        let current = try JSONDecoder().decode(CaptureMode.self, from: Data(#""current""#.utf8))
        let proposed = try JSONDecoder().decode(CaptureMode.self, from: Data(#""proposed""#.utf8))

        XCTAssertEqual(current, .create)
        XCTAssertEqual(proposed, .update)
    }

    func testTwinLifecycleFieldsDefaultOnLegacyDecode() throws {
        let json = "[{\"id\":\"00000000-0000-0000-0000-000000000099\",\"reference\":\"VIS-LEGACY-ID\",\"createdAt\":\"2024-01-01T00:00:00Z\",\"twinKind\":\"home\",\"rooms\":[],\"components\":[]}]"
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let visits = try decoder.decode([Visit].self, from: Data(json.utf8))
        XCTAssertEqual(visits[0].repositoryState, .localWorkingCopy)
        XCTAssertEqual(visits[0].lifecycleStage, .capture)
        XCTAssertEqual(visits[0].twinVersion, 1)
        XCTAssertNil(visits[0].lastMergedAt)
    }

    func testTwinVersionAndLastMergedRoundTrip() throws {
        let mergedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let visit = Visit(
            reference: "VIS-VERSION",
            twinKind: .system,
            repositoryState: .merged,
            lifecycleStage: .merge,
            twinVersion: 27,
            lastMergedAt: mergedAt
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(VisitPackage(visits: [visit]))

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(VisitPackage.self, from: data)

        XCTAssertEqual(decoded.visits[0].twinVersion, 27)
        XCTAssertEqual(decoded.visits[0].lastMergedAt, mergedAt)
        XCTAssertEqual(decoded.visits[0].repositoryState, .merged)
        XCTAssertEqual(decoded.visits[0].lifecycleStage, .merge)
    }

    func testSpatialEvidenceContextRoundTrip() throws {
        let component = SystemComponent(
            kind: .boiler,
            canonicalSubtype: .combiBoiler,
            spatialContext: SpatialEvidenceContext(
                floorLevel: "Ground floor",
                areaLabel: "Utility",
                geometryID: "wall-east-01",
                approximatePositionLabel: "Left of cylinder"
            )
        )
        let visit = Visit(reference: "VIS-SPATIAL-CONTEXT", twinKind: .system, components: [component])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(VisitPackage(visits: [visit]))

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(VisitPackage.self, from: data)

        let context = decoded.visits[0].components[0].spatialContext
        XCTAssertEqual(context?.floorLevel, "Ground floor")
        XCTAssertEqual(context?.areaLabel, "Utility")
        XCTAssertEqual(context?.geometryID, "wall-east-01")
        XCTAssertEqual(context?.approximatePositionLabel, "Left of cylinder")
    }

    func testEvidenceTrustDefaultsFromEvidenceKind() throws {
        XCTAssertEqual(Evidence(kind: .photo, localFileName: "photo.jpg").trustLevel, .photos)
        XCTAssertEqual(Evidence(kind: .voiceNote, localFileName: "note.m4a").trustLevel, .humanObservations)
        XCTAssertEqual(Evidence(kind: .textNote, localFileName: "note.txt").trustLevel, .humanObservations)
    }

    func testVisitEncodingQuarantinesLegacyProposedSystemFields() throws {
        let visit = Visit(
            reference: "VIS-LIFECYCLE",
            twinKind: .system,
            currentSystemType: .combi,
            legacySystemType: .regularSealed,
            captureMode: .verify,
            sectionStatuses: [.boiler: .present],
            legacySectionStatuses: [.cylinder: .notPresent]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(VisitPackage(visits: [visit]))
        let encodedJSON = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(encodedJSON.contains(#""captureMode":"verify""#))
        XCTAssertTrue(encodedJSON.contains(#""currentSystemType":"combi""#))
        XCTAssertFalse(encodedJSON.contains("proposedSystemType"))
        XCTAssertFalse(encodedJSON.contains("proposedSectionStatuses"))
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
        XCTAssertEqual(component.canonicalSubtype, .unknownHeatSource)
        XCTAssertEqual(component.componentAttributes, [:])
        XCTAssertNil(component.reviewStatus)
        XCTAssertNil(component.reviewNotes)
        XCTAssertEqual(component.spatialPlacement.captureState, .unspecified)
    }

    func testVisitDecodesLegacyPayloadWithoutRelationships() throws {
        let json = "[{\"id\":\"00000000-0000-0000-0000-000000000099\",\"reference\":\"VIS-LEGACY-ID\",\"createdAt\":\"2024-01-01T00:00:00Z\",\"twinKind\":\"home\",\"rooms\":[],\"components\":[]}]"
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let visits = try decoder.decode([Visit].self, from: Data(json.utf8))
        XCTAssertEqual(visits[0].relationships, [])
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
        XCTAssertEqual(room.spatialPlacement.captureState, .unspecified)
    }

    func testMVPSmokeCaptureLoopRoundTrip() throws {
        var visit = Visit(reference: "MVP-001", twinKind: .home)
        visit.rooms.append(
            Room(
                name: "Kitchen",
                reviewStatus: .needsReview,
                reviewNotes: "Room capture pending confirmation.",
                survey: [
                    "heating.emitters.present": SurveyResponse(booleanValue: true, reviewStatus: .confirmed)
                ],
                evidence: [
                    Evidence(
                        kind: .photo,
                        localFileName: "kitchen-photo.jpg",
                        reviewStatus: .needsReview,
                        reviewNotes: "Recheck framing."
                    ),
                    Evidence(
                        kind: .voiceNote,
                        localFileName: "kitchen-note.m4a",
                        reviewStatus: .draft,
                        reviewNotes: "Engineer verbal note."
                    ),
                    Evidence(
                        kind: .textNote,
                        localFileName: "kitchen-note.txt",
                        reviewStatus: .confirmed,
                        reviewNotes: "Text evidence captured."
                    )
                ],
                spatialPlacement: SpatialPlacement(captureState: .approximate, confidence: .low)
            )
        )
        visit.components.append(
            SystemComponent(
                kind: .boiler,
                name: "Boiler A",
                reviewStatus: .confirmed,
                reviewNotes: "Boiler reviewed.",
                spatialPlacement: SpatialPlacement(captureState: .areaReferenceOnly, confidence: .low)
            )
        )
        visit.components.append(
            SystemComponent(
                kind: .flue,
                name: "Flue A",
                reviewStatus: .draft,
                reviewNotes: "Flue initial capture.",
                spatialPlacement: SpatialPlacement(captureState: .failed, confidence: .unknown)
            )
        )
        visit.components.append(
            SystemComponent(
                kind: .controls,
                name: "Controls A",
                reviewStatus: .needsReview,
                reviewNotes: "Controls review required.",
                spatialPlacement: SpatialPlacement(captureState: .areaReferenceOnly, confidence: .low)
            )
        )
        visit.sectionStatuses[.boiler] = .present
        visit.sectionStatuses[.flue] = .notAccessible

        let encoded = try JSONEncoder.iso8601Encoded.encode(VisitPackage(visits: [visit]))
        let decoded = try JSONDecoder.iso8601Decoded.decode(VisitPackage.self, from: encoded)
        let roundTripped = decoded.visits[0]

        XCTAssertEqual(roundTripped.reference, "MVP-001")
        XCTAssertEqual(roundTripped.rooms.count, 1)
        XCTAssertEqual(roundTripped.rooms[0].name, "Kitchen")
        XCTAssertEqual(roundTripped.rooms[0].evidence.map(\.kind), [.photo, .voiceNote, .textNote])
        XCTAssertEqual(roundTripped.rooms[0].evidence[0].reviewStatus, .needsReview)
        XCTAssertEqual(roundTripped.rooms[0].evidence[1].reviewNotes, "Engineer verbal note.")
        XCTAssertEqual(roundTripped.rooms[0].survey["heating.emitters.present"]?.reviewStatus, .confirmed)
        XCTAssertEqual(roundTripped.rooms[0].spatialPlacement.captureState, .approximate)
        XCTAssertEqual(roundTripped.components.map(\.kind), [.boiler, .flue, .controls])
        XCTAssertEqual(roundTripped.components[0].reviewStatus, .confirmed)
        XCTAssertEqual(roundTripped.components[1].spatialPlacement.captureState, .failed)
        XCTAssertEqual(roundTripped.sectionStatuses[.boiler], .present)
        XCTAssertEqual(roundTripped.sectionStatuses[.flue], .notAccessible)
    }

    func testMVPSmokeConflictReplaceExistingVisit() {
        let sharedID = UUID()
        let existing = Visit(id: sharedID, reference: "VIS-100", twinKind: .home, notes: "Original")
        let imported = Visit(id: sharedID, reference: "VIS-100", twinKind: .system, notes: "Imported replacement")

        let merged = VisitImportMerger.merge(
            existingVisits: [existing],
            importedVisits: [imported],
            strategy: .replaceExistingVisit
        )

        XCTAssertEqual(merged.visits.count, 1)
        XCTAssertEqual(merged.replacedVisits.count, 1)
        XCTAssertEqual(merged.replacedVisits[0].id, existing.id)
        XCTAssertEqual(merged.visits[0].id, sharedID)
        XCTAssertEqual(merged.visits[0].notes, "Imported replacement")
    }

    func testMVPSmokeConflictKeepBothCreatesImportedCopy() {
        let sharedID = UUID()
        let existing = Visit(id: sharedID, reference: "VIS-200", twinKind: .home)
        let imported = Visit(id: sharedID, reference: "VIS-200", twinKind: .system)

        let merged = VisitImportMerger.merge(
            existingVisits: [existing],
            importedVisits: [imported],
            strategy: .keepBoth
        )

        XCTAssertEqual(merged.replacedVisits.count, 0)
        XCTAssertEqual(merged.visits.count, 2)
        XCTAssertEqual(merged.visits[0].id, sharedID)
        XCTAssertEqual(merged.visits[0].reference, "VIS-200")

        let copiedVisit = merged.visits[1]
        XCTAssertNotEqual(copiedVisit.id, sharedID)
        XCTAssertEqual(copiedVisit.twinKind, .system)
        XCTAssertEqual(copiedVisit.reference, "VIS-200 (Imported copy)")
    }
}

private extension JSONEncoder {
    static var iso8601Encoded: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var iso8601Decoded: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
