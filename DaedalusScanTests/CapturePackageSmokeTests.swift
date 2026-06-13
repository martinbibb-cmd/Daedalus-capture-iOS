import XCTest
@testable import DaedalusScanCore

@MainActor
final class CapturePackageSmokeTests: XCTestCase {
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
