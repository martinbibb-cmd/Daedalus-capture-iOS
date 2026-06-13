import XCTest
@testable import DaedalusScanCore

@MainActor
final class VisitRecordingTests: XCTestCase {
    func testVisitRecordingChunksAttachAndPersistInOrder() throws {
        let storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaedalusRecordings-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: storageDirectory)
        }

        let repository = VisitRepository(storageDirectory: storageDirectory)
        let viewModel = VisitListViewModel(repository: repository)
        let visitID = try XCTUnwrap(viewModel.createVisit(reference: "42 Elm Street"))

        let start = Date(timeIntervalSince1970: 1_700_000_000)
        for sequenceNumber in 1...3 {
            let prepared = try XCTUnwrap(viewModel.prepareVisitRecordingChunkURL(for: visitID))
            XCTAssertEqual(prepared.sequenceNumber, sequenceNumber)
            try Data([UInt8(sequenceNumber)]).write(to: prepared.url, options: .atomic)
            let recordingID = try XCTUnwrap(
                viewModel.attachVisitRecordingChunk(
                    localFileName: prepared.url.lastPathComponent,
                    sequenceNumber: prepared.sequenceNumber,
                    startedAt: start.addingTimeInterval(Double(sequenceNumber - 1) * 300),
                    to: visitID
                )
            )
            viewModel.completeVisitRecordingChunk(
                recordingID: recordingID,
                visitID: visitID,
                endedAt: start.addingTimeInterval(Double(sequenceNumber) * 300),
                status: .completed
            )
        }

        let reloaded = VisitListViewModel(repository: repository)
        let visit = try XCTUnwrap(reloaded.visit(id: visitID))

        XCTAssertEqual(visit.recordings.map(\.sequenceNumber), [1, 2, 3])
        XCTAssertEqual(visit.recordings.map(\.displayName), ["Recording 001", "Recording 002", "Recording 003"])
        XCTAssertEqual(visit.recordings.map(\.status), [.completed, .completed, .completed])
        XCTAssertEqual(visit.recordings.map(\.duration), [300, 300, 300])
        XCTAssertTrue(visit.recordings.allSatisfy { $0.localFileName.hasSuffix(".m4a") })
    }

    func testInterruptedRecordingCanResumeAsNextChunk() throws {
        let storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaedalusRecordingResume-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: storageDirectory)
        }

        let viewModel = VisitListViewModel(repository: VisitRepository(storageDirectory: storageDirectory))
        let visitID = try XCTUnwrap(viewModel.createVisit(reference: "42 Elm Street"))

        let first = try XCTUnwrap(viewModel.prepareVisitRecordingChunkURL(for: visitID))
        let firstID = try XCTUnwrap(
            viewModel.attachVisitRecordingChunk(
                localFileName: first.url.lastPathComponent,
                sequenceNumber: first.sequenceNumber,
                to: visitID
            )
        )
        viewModel.completeVisitRecordingChunk(recordingID: firstID, visitID: visitID, status: .interrupted)

        let resumed = try XCTUnwrap(viewModel.prepareVisitRecordingChunkURL(for: visitID))
        let resumedID = try XCTUnwrap(
            viewModel.attachVisitRecordingChunk(
                localFileName: resumed.url.lastPathComponent,
                sequenceNumber: resumed.sequenceNumber,
                to: visitID
            )
        )
        viewModel.completeVisitRecordingChunk(recordingID: resumedID, visitID: visitID, status: .completed)

        let visit = try XCTUnwrap(viewModel.visit(id: visitID))
        XCTAssertEqual(visit.recordings.map(\.sequenceNumber), [1, 2])
        XCTAssertEqual(visit.recordings.map(\.status), [.interrupted, .completed])
    }

    func testTranscriptCanAttachToRecordingAndPersistStatusTextAndChunks() throws {
        let storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaedalusTranscript-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: storageDirectory)
        }

        let repository = VisitRepository(storageDirectory: storageDirectory)
        let viewModel = VisitListViewModel(repository: repository)
        let visitID = try XCTUnwrap(viewModel.createVisit(reference: "42 Elm Street"))
        let prepared = try XCTUnwrap(viewModel.prepareVisitRecordingChunkURL(for: visitID))
        let recordingID = try XCTUnwrap(
            viewModel.attachVisitRecordingChunk(
                localFileName: prepared.url.lastPathComponent,
                sequenceNumber: prepared.sequenceNumber,
                to: visitID
            )
        )
        let transcriptID = try XCTUnwrap(
            viewModel.attachTranscript(sourceRecordingID: recordingID, status: .pending, to: visitID)
        )

        viewModel.updateTranscript(
            transcriptID: transcriptID,
            visitID: visitID,
            status: .complete,
            rawTranscript: "Boiler cupboard noted.",
            chunks: [
                TranscriptChunk(
                    sourceRecordingID: recordingID,
                    startTime: 4,
                    endTime: 9,
                    text: "Boiler cupboard noted."
                )
            ]
        )

        let reloaded = VisitListViewModel(repository: repository)
        let visit = try XCTUnwrap(reloaded.visit(id: visitID))
        XCTAssertEqual(visit.transcripts.count, 1)
        XCTAssertEqual(visit.transcripts[0].source.recordingID, recordingID)
        XCTAssertEqual(visit.transcripts[0].source.localFileName, prepared.url.lastPathComponent)
        XCTAssertEqual(visit.transcripts[0].status, .complete)
        XCTAssertEqual(visit.transcripts[0].rawTranscript, "Boiler cupboard noted.")
        XCTAssertEqual(visit.transcripts[0].chunks[0].startTime, 4)
        XCTAssertEqual(visit.transcripts[0].chunks[0].endTime, 9)
    }

    func testOfflineTranscriptionQueueUsesProviderAndPersistsResult() async throws {
        let storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaedalusTranscriptionQueue-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: storageDirectory)
        }

        let repository = VisitRepository(storageDirectory: storageDirectory)
        let viewModel = VisitListViewModel(repository: repository)
        let visitID = try XCTUnwrap(viewModel.createVisit(reference: "42 Elm Street"))
        let prepared = try XCTUnwrap(viewModel.prepareVisitRecordingChunkURL(for: visitID))
        let recordingID = try XCTUnwrap(
            viewModel.attachVisitRecordingChunk(
                localFileName: prepared.url.lastPathComponent,
                sequenceNumber: prepared.sequenceNumber,
                to: visitID
            )
        )
        let provider = FakeTranscriptionProvider(
            result: TranscriptionProviderResult(
                status: .complete,
                rawTranscript: "Pipework seen below cylinder.",
                chunks: [
                    TranscriptChunk(
                        sourceRecordingID: recordingID,
                        startTime: 1,
                        endTime: 3,
                        text: "Pipework seen below cylinder."
                    )
                ]
            )
        )
        let queue = OfflineTranscriptionQueue(provider: provider, viewModel: viewModel)
        let transcriptID = try XCTUnwrap(queue.enqueue(recordingID: recordingID, visitID: visitID, fileURL: prepared.url))

        XCTAssertEqual(viewModel.visit(id: visitID)?.transcripts.first?.status, .pending)

        await queue.processNext()

        let reloaded = VisitListViewModel(repository: repository)
        let transcript = try XCTUnwrap(reloaded.visit(id: visitID)?.transcripts.first { $0.id == transcriptID })
        XCTAssertEqual(transcript.status, .complete)
        XCTAssertEqual(transcript.rawTranscript, "Pipework seen below cylinder.")
        XCTAssertEqual(transcript.chunks.first?.text, "Pipework seen below cylinder.")
        XCTAssertTrue(queue.items.isEmpty)
    }

    func testEvidenceCanStoreTranscriptReferenceWithoutTranscriptText() throws {
        let storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaedalusEvidenceTranscriptLink-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: storageDirectory)
        }

        let repository = VisitRepository(storageDirectory: storageDirectory)
        let viewModel = VisitListViewModel(repository: repository)
        let visitID = try XCTUnwrap(viewModel.createVisit(reference: "42 Elm Street"))
        let componentID = try XCTUnwrap(
            viewModel.addSpatialObject(
                to: visitID,
                kind: .boiler,
                subtype: .unknownHeatSource,
                areaID: nil
            )
        )
        viewModel.attachQuickEvidencePhoto(data: Data([0xFF, 0xD8]), toComponent: componentID, in: visitID)
        let evidenceID = try XCTUnwrap(viewModel.component(visitID: visitID, componentID: componentID)?.evidence.first?.id)

        let prepared = try XCTUnwrap(viewModel.prepareVisitRecordingChunkURL(for: visitID))
        let recordingID = try XCTUnwrap(
            viewModel.attachVisitRecordingChunk(
                localFileName: prepared.url.lastPathComponent,
                sequenceNumber: prepared.sequenceNumber,
                to: visitID
            )
        )
        let chunk = TranscriptChunk(
            sourceRecordingID: recordingID,
            startTime: 10,
            endTime: 14,
            text: "Boiler photo taken."
        )
        let transcriptID = try XCTUnwrap(
            viewModel.attachTranscript(
                sourceRecordingID: recordingID,
                status: .complete,
                rawTranscript: "Boiler photo taken.",
                chunks: [chunk],
                to: visitID
            )
        )
        let reference = EvidenceTranscriptReference(
            transcriptID: transcriptID,
            chunkID: chunk.id,
            sourceRecordingID: recordingID
        )

        viewModel.linkTranscriptReferenceToComponentEvidence(
            reference,
            evidenceID: evidenceID,
            componentID: componentID,
            visitID: visitID
        )

        let reloaded = VisitListViewModel(repository: repository)
        let reloadedEvidence = try XCTUnwrap(reloaded.component(visitID: visitID, componentID: componentID)?.evidence.first)
        XCTAssertEqual(reloadedEvidence.transcriptReferences, [reference])
    }

    func testFullVisitExportEmbedsEvidenceRecordingsAndTranscriptsForImport() throws {
        let sourceDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaedalusFullExportSource-\(UUID().uuidString)", isDirectory: true)
        let importDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaedalusFullExportImport-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: sourceDirectory)
            try? FileManager.default.removeItem(at: importDirectory)
        }

        let sourceRepository = VisitRepository(storageDirectory: sourceDirectory)
        let sourceViewModel = VisitListViewModel(repository: sourceRepository)
        let visitID = try XCTUnwrap(sourceViewModel.createVisit(reference: "42 Elm Street"))
        let componentID = try XCTUnwrap(
            sourceViewModel.addSpatialObject(
                to: visitID,
                kind: .boiler,
                subtype: .unknownHeatSource,
                areaID: nil
            )
        )
        sourceViewModel.attachQuickEvidencePhoto(data: Data([0xFF, 0xD8]), toComponent: componentID, in: visitID)

        let prepared = try XCTUnwrap(sourceViewModel.prepareVisitRecordingChunkURL(for: visitID))
        let recordingBytes = Data([0x00, 0x01, 0x02])
        try recordingBytes.write(to: prepared.url, options: .atomic)
        let recordingID = try XCTUnwrap(
            sourceViewModel.attachVisitRecordingChunk(
                localFileName: prepared.url.lastPathComponent,
                sequenceNumber: prepared.sequenceNumber,
                to: visitID
            )
        )
        let chunk = TranscriptChunk(sourceRecordingID: recordingID, startTime: 1, endTime: 2, text: "Boiler recorded.")
        _ = try XCTUnwrap(
            sourceViewModel.attachTranscript(
                sourceRecordingID: recordingID,
                status: .complete,
                rawTranscript: "Boiler recorded.",
                chunks: [chunk],
                to: visitID
            )
        )

        let package = try sourceRepository.exportPackage(visits: [try XCTUnwrap(sourceViewModel.visit(id: visitID))])
        XCTAssertEqual(package.visits[0].components[0].evidence[0].embeddedData, Data([0xFF, 0xD8]))
        XCTAssertEqual(package.visits[0].recordings[0].embeddedData, recordingBytes)
        XCTAssertEqual(package.visits[0].transcripts[0].rawTranscript, "Boiler recorded.")

        let exportURL = sourceDirectory.appendingPathComponent("export.daedalusscan")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(package).write(to: exportURL, options: .atomic)

        let imported = try VisitRepository(storageDirectory: importDirectory)
            .importPackage(from: exportURL)
        let importedVisit = try XCTUnwrap(imported.first)
        let importedEvidence = try XCTUnwrap(importedVisit.components.first?.evidence.first)
        let importedRecording = try XCTUnwrap(importedVisit.recordings.first)

        XCTAssertNil(importedEvidence.embeddedData)
        XCTAssertNil(importedRecording.embeddedData)
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

    func testCaptureRecoverySnapshotPersistsActiveVisitRecordingAndDraftEvidence() throws {
        let storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaedalusCaptureRecovery-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: storageDirectory)
        }

        let repository = VisitRepository(storageDirectory: storageDirectory)
        let viewModel = VisitListViewModel(repository: repository)
        let visitID = try XCTUnwrap(viewModel.createVisit(reference: "42 Elm Street"))
        let prepared = try XCTUnwrap(viewModel.prepareVisitRecordingChunkURL(for: visitID))
        let recordingID = try XCTUnwrap(
            viewModel.attachVisitRecordingChunk(
                localFileName: prepared.url.lastPathComponent,
                sequenceNumber: prepared.sequenceNumber,
                to: visitID
            )
        )
        viewModel.saveCaptureRecoverySnapshot(
            CaptureRecoverySnapshot(
                visitID: visitID,
                activeRecordingID: recordingID,
                activeRecordingFileName: prepared.url.lastPathComponent,
                shouldOfferResumeRecording: true
            )
        )
        let draftID = try XCTUnwrap(
            viewModel.trackUnsavedEvidenceDraft(
                visitID: visitID,
                evidenceKind: .photo,
                localFileName: "pending-photo.jpg",
                note: "Seen before save"
            )
        )

        let reloaded = VisitListViewModel(repository: repository)
        let snapshot = try XCTUnwrap(reloaded.pendingCaptureRecoverySnapshot)
        XCTAssertEqual(snapshot.visitID, visitID)
        XCTAssertEqual(snapshot.activeRecordingID, recordingID)
        XCTAssertEqual(snapshot.activeRecordingFileName, prepared.url.lastPathComponent)
        XCTAssertTrue(snapshot.shouldOfferResumeRecording)
        XCTAssertEqual(snapshot.unsavedEvidenceDrafts.map(\.id), [draftID])
        XCTAssertEqual(snapshot.unsavedEvidenceDrafts.first?.evidenceKind, .photo)
        XCTAssertEqual(snapshot.unsavedEvidenceDrafts.first?.note, "Seen before save")
    }

    func testCaptureRecoveryClearsWhenDraftsAreDiscarded() throws {
        let storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaedalusCaptureRecoveryClear-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: storageDirectory)
        }

        let repository = VisitRepository(storageDirectory: storageDirectory)
        let viewModel = VisitListViewModel(repository: repository)
        let visitID = try XCTUnwrap(viewModel.createVisit(reference: "42 Elm Street"))
        let draftID = try XCTUnwrap(
            viewModel.trackUnsavedEvidenceDraft(
                visitID: visitID,
                evidenceKind: .textNote,
                note: "Unmapped note"
            )
        )

        XCTAssertNotNil(viewModel.pendingCaptureRecoverySnapshot)

        viewModel.discardUnsavedEvidenceDraft(draftID)

        XCTAssertNil(viewModel.pendingCaptureRecoverySnapshot)
        XCTAssertNil(VisitListViewModel(repository: repository).pendingCaptureRecoverySnapshot)
    }
}

private struct FakeTranscriptionProvider: TranscriptionProvider {
    let kind: TranscriptionProviderKind = .native
    let result: TranscriptionProviderResult

    func transcribe(recording: VisitRecording, fileURL: URL) async -> TranscriptionProviderResult {
        result
    }
}
