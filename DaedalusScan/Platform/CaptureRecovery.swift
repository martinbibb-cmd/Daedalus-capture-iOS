import Foundation

enum CaptureRecoveryDraftContextKind: String, Codable, Hashable, Sendable {
    case visit
    case room
    case component
}

struct RecoveredEvidenceDraft: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var visitID: UUID
    var contextID: UUID?
    var contextKind: CaptureRecoveryDraftContextKind
    var evidenceKind: EvidenceKind
    var localFileName: String?
    var note: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        visitID: UUID,
        contextID: UUID? = nil,
        contextKind: CaptureRecoveryDraftContextKind = .visit,
        evidenceKind: EvidenceKind,
        localFileName: String? = nil,
        note: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.visitID = visitID
        self.contextID = contextID
        self.contextKind = contextKind
        self.evidenceKind = evidenceKind
        self.localFileName = localFileName
        self.note = note
        self.createdAt = createdAt
    }
}

struct CaptureRecoverySnapshot: Codable, Hashable, Sendable {
    var visitID: UUID
    var activeRecordingID: UUID?
    var activeRecordingFileName: String?
    var shouldOfferResumeRecording: Bool
    var unsavedEvidenceDrafts: [RecoveredEvidenceDraft]
    var updatedAt: Date

    init(
        visitID: UUID,
        activeRecordingID: UUID? = nil,
        activeRecordingFileName: String? = nil,
        shouldOfferResumeRecording: Bool = false,
        unsavedEvidenceDrafts: [RecoveredEvidenceDraft] = [],
        updatedAt: Date = Date()
    ) {
        self.visitID = visitID
        self.activeRecordingID = activeRecordingID
        self.activeRecordingFileName = activeRecordingFileName
        self.shouldOfferResumeRecording = shouldOfferResumeRecording
        self.unsavedEvidenceDrafts = unsavedEvidenceDrafts
        self.updatedAt = updatedAt
    }
}
