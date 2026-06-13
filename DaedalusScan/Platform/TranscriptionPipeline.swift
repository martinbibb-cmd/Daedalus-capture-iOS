import Combine
import Foundation

public enum TranscriptionProviderKind: String, Codable, CaseIterable, Hashable, Sendable {
    case native
    case remoteLLM
}

public struct TranscriptionProviderResult: Hashable, Sendable {
    public var status: TranscriptStatus
    public var rawTranscript: String
    public var chunks: [TranscriptChunk]
    public var failureReason: String?

    public init(
        status: TranscriptStatus,
        rawTranscript: String = "",
        chunks: [TranscriptChunk] = [],
        failureReason: String? = nil
    ) {
        self.status = status
        self.rawTranscript = rawTranscript
        self.chunks = chunks
        self.failureReason = failureReason
    }
}

public protocol TranscriptionProvider: Sendable {
    var kind: TranscriptionProviderKind { get }

    func transcribe(recording: VisitRecording, fileURL: URL) async -> TranscriptionProviderResult
}

public struct NativeTranscriptionProvider: TranscriptionProvider {
    public let kind: TranscriptionProviderKind = .native

    public init() {}

    public func transcribe(recording: VisitRecording, fileURL: URL) async -> TranscriptionProviderResult {
        TranscriptionProviderResult(
            status: .failed,
            failureReason: "Native transcription provider is not connected yet."
        )
    }
}

public struct RemoteLLMProvider: TranscriptionProvider {
    public let kind: TranscriptionProviderKind = .remoteLLM

    public init() {}

    public func transcribe(recording: VisitRecording, fileURL: URL) async -> TranscriptionProviderResult {
        TranscriptionProviderResult(
            status: .failed,
            failureReason: "Remote transcription provider is a stub."
        )
    }
}

public struct TranscriptionQueueItem: Hashable, Identifiable, Sendable {
    public let id: UUID
    public var visitID: UUID
    public var recordingID: UUID
    public var transcriptID: UUID
    public var fileURL: URL
    public var enqueuedAt: Date

    public init(
        id: UUID = UUID(),
        visitID: UUID,
        recordingID: UUID,
        transcriptID: UUID,
        fileURL: URL,
        enqueuedAt: Date = Date()
    ) {
        self.id = id
        self.visitID = visitID
        self.recordingID = recordingID
        self.transcriptID = transcriptID
        self.fileURL = fileURL
        self.enqueuedAt = enqueuedAt
    }
}

@MainActor
public final class OfflineTranscriptionQueue: ObservableObject {
    @Published public private(set) var items: [TranscriptionQueueItem] = []
    @Published public private(set) var isProcessing = false

    private let provider: TranscriptionProvider
    private let viewModel: VisitListViewModel

    public init(provider: TranscriptionProvider, viewModel: VisitListViewModel) {
        self.provider = provider
        self.viewModel = viewModel
    }

    @discardableResult
    public func enqueue(recordingID: UUID, visitID: UUID, fileURL: URL) -> UUID? {
        guard let transcriptID = viewModel.attachTranscript(
            sourceRecordingID: recordingID,
            status: .pending,
            to: visitID
        ) else {
            return nil
        }
        items.append(
            TranscriptionQueueItem(
                visitID: visitID,
                recordingID: recordingID,
                transcriptID: transcriptID,
                fileURL: fileURL
            )
        )
        return transcriptID
    }

    public func processNext() async {
        guard !isProcessing, let item = items.first else { return }
        guard let recording = viewModel.visit(id: item.visitID)?.recordings.first(where: { $0.id == item.recordingID }) else {
            items.removeFirst()
            return
        }

        isProcessing = true
        viewModel.updateTranscript(
            transcriptID: item.transcriptID,
            visitID: item.visitID,
            status: .processing,
            rawTranscript: "",
            chunks: []
        )

        let result = await provider.transcribe(recording: recording, fileURL: item.fileURL)
        viewModel.updateTranscript(
            transcriptID: item.transcriptID,
            visitID: item.visitID,
            status: result.status,
            rawTranscript: result.rawTranscript,
            chunks: result.chunks,
            failureReason: result.failureReason
        )
        items.removeFirst()
        isProcessing = false
    }
}
