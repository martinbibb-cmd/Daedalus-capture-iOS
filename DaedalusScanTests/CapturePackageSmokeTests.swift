import XCTest
@testable import DaedalusScanCore

@MainActor
final class CapturePackageSmokeTests: XCTestCase {
    func testOfflineCaptureCreatesPropertyRootedSurveyPackage() throws {
        let sourceDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaedalusPropertyRootedCapture-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: sourceDirectory)
        }

        let repository = VisitRepository(storageDirectory: sourceDirectory)
        let viewModel = VisitListViewModel(repository: repository)
        let visitID = try XCTUnwrap(
            viewModel.createVisit(
                reference: "PROP-001",
                customerName: "Offline Customer",
                addressLine: "1 Local Lane",
                postcode: "ab1 2cd"
            )
        )

        viewModel.addRoom(to: visitID, named: "Plant Room")
        let areaID = try XCTUnwrap(viewModel.visit(id: visitID)?.areas.first?.id)
        let componentID = try XCTUnwrap(
            viewModel.addAREvidenceCapture(
                to: visitID,
                subtype: .combiBoiler,
                areaID: areaID,
                placement: SpatialPlacement(captureState: .areaReferenceOnly, confidence: .low),
                photoData: Data([0xFF, 0xD8, 0xFF]),
                voiceNoteText: "Boiler photographed offline.",
                includeGeometry: true,
                floorLevel: "Ground floor",
                geometryID: "plant-wall",
                approximatePositionLabel: "North wall"
            )
        )

        let visit = try XCTUnwrap(viewModel.visit(id: visitID))
        XCTAssertEqual(visit.propertyIdentity.reference, "PROP-001")
        XCTAssertEqual(visit.propertyIdentity.postcode, "AB1 2CD")
        XCTAssertEqual(visit.workingTwin.propertyID, visit.propertyIdentity.id)
        XCTAssertEqual(visit.captureSession.propertyID, visit.propertyIdentity.id)
        XCTAssertEqual(visit.captureSession.workingTwinID, visit.workingTwin.id)
        XCTAssertTrue(visit.captureSession.isOffline)

        let evidence = try XCTUnwrap(viewModel.component(visitID: visitID, componentID: componentID)?.evidence)
        XCTAssertFalse(evidence.isEmpty)
        XCTAssertTrue(evidence.allSatisfy { $0.propertyID == visit.propertyIdentity.id })
        XCTAssertTrue(evidence.allSatisfy { $0.workingTwinID == visit.workingTwin.id })
        XCTAssertTrue(evidence.allSatisfy { $0.captureSessionID == visit.captureSession.id })

        let package = try repository.exportPackage(visits: [visit])
        XCTAssertEqual(package.schemaVersion, 4)
        XCTAssertEqual(package.propertyRoots.first?.property, visit.propertyIdentity)
        XCTAssertEqual(package.metadata?.propertyRoots.first?.workingTwin.id, visit.workingTwin.id)
        XCTAssertEqual(package.visits.first?.propertyRootMetadata.captureSession.id, visit.captureSession.id)
    }

    func testEndToEndCapturePackageSurvivesExportImportRoundTrip() throws {
        let sourceDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaedalusPackageSmokeSource-\(UUID().uuidString)", isDirectory: true)
        let importDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaedalusPackageSmokeImport-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: sourceDirectory)
            try? FileManager.default.removeItem(at: importDirectory)
        }

        let sourceRepository = VisitRepository(storageDirectory: sourceDirectory)
        let sourceViewModel = VisitListViewModel(repository: sourceRepository)
        let visitID = try XCTUnwrap(sourceViewModel.createVisit(reference: "42 Elm Street"))
        sourceViewModel.addRoom(to: visitID, named: "Utility")
        let roomID = try XCTUnwrap(sourceViewModel.visit(id: visitID)?.rooms.first?.id)
        let componentID = try XCTUnwrap(
            sourceViewModel.addSpatialObject(
                to: visitID,
                kind: .boiler,
                subtype: .unknownHeatSource,
                areaID: roomID,
                placement: SpatialPlacement(captureState: .areaReferenceOnly, confidence: .low)
            )
        )

        sourceViewModel.attachQuickEvidencePhoto(data: Data([0xFF, 0xD8, 0xFF]), toComponent: componentID, in: visitID)
        let preparedRecording = try XCTUnwrap(sourceViewModel.prepareVisitRecordingChunkURL(for: visitID))
        let recordingBytes = Data([0x00, 0x01, 0x02, 0x03])
        try recordingBytes.write(to: preparedRecording.url, options: .atomic)
        let recordingID = try XCTUnwrap(
            sourceViewModel.attachVisitRecordingChunk(
                localFileName: preparedRecording.url.lastPathComponent,
                sequenceNumber: preparedRecording.sequenceNumber,
                to: visitID
            )
        )
        let transcriptChunk = TranscriptChunk(
            sourceRecordingID: recordingID,
            startTime: 2,
            endTime: 7,
            text: "Boiler seen in utility."
        )
        let transcriptID = try XCTUnwrap(
            sourceViewModel.attachTranscript(
                sourceRecordingID: recordingID,
                status: .complete,
                rawTranscript: "Boiler seen in utility.",
                chunks: [transcriptChunk],
                to: visitID
            )
        )
        let evidenceID = try XCTUnwrap(sourceViewModel.component(visitID: visitID, componentID: componentID)?.evidence.first?.id)
        sourceViewModel.linkTranscriptReferenceToComponentEvidence(
            EvidenceTranscriptReference(
                transcriptID: transcriptID,
                chunkID: transcriptChunk.id,
                sourceRecordingID: recordingID
            ),
            evidenceID: evidenceID,
            componentID: componentID,
            visitID: visitID
        )

        let package = try sourceRepository.exportPackage(visits: [try XCTUnwrap(sourceViewModel.visit(id: visitID))])
        let exportURL = sourceDirectory.appendingPathComponent("capture-smoke.daedalusscan")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(package).write(to: exportURL, options: .atomic)

        let importedVisits = try VisitRepository(storageDirectory: importDirectory).importPackage(from: exportURL)
        let importedVisit = try XCTUnwrap(importedVisits.first)
        let importedComponent = try XCTUnwrap(importedVisit.components.first)
        let importedEvidence = try XCTUnwrap(importedComponent.evidence.first)
        let importedRecording = try XCTUnwrap(importedVisit.recordings.first)
        let importedTranscript = try XCTUnwrap(importedVisit.transcripts.first)

        XCTAssertEqual(importedVisit.reference, "42 Elm Street")
        XCTAssertEqual(importedVisit.rooms.map(\.name), ["Utility"])
        XCTAssertEqual(importedComponent.canonicalSubtype, .unknownHeatSource)
        XCTAssertEqual(importedComponent.spatialPlacement.captureState, .areaReferenceOnly)
        XCTAssertEqual(importedEvidence.kind, .photo)
        XCTAssertEqual(importedEvidence.transcriptReferences.first?.transcriptID, importedTranscript.id)
        XCTAssertEqual(importedRecording.sequenceNumber, 1)
        XCTAssertEqual(importedTranscript.rawTranscript, "Boiler seen in utility.")
        XCTAssertEqual(importedTranscript.chunks.first?.text, "Boiler seen in utility.")
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: importDirectory
                    .appendingPathComponent("Evidence", isDirectory: true)
                    .appendingPathComponent(importedEvidence.localFileName)
                    .path
            )
        )
        XCTAssertEqual(
            try Data(
                contentsOf: importDirectory
                    .appendingPathComponent("Recordings", isDirectory: true)
                    .appendingPathComponent(importedRecording.localFileName)
            ),
            recordingBytes
        )
    }
}
