import Foundation

struct EvidenceTimelineEntry: Identifiable, Equatable {
    let id: UUID
    let capturedAt: Date
    let evidenceType: String
    let componentID: UUID?
    let componentTitle: String
    let spatialContext: String?
    let reviewStatus: ReviewStatus?
    let isMerged: Bool
}

enum VisitTimelineEntryKind: String, Equatable {
    case photo
    case voiceNote
    case note
    case mark
    case safety
    case recordingChunk
    case transcript
    case roomScan

    var title: String {
        switch self {
        case .photo: return "Photo"
        case .voiceNote: return "Voice Note"
        case .note: return "Note"
        case .mark: return "Mark"
        case .safety: return "Safety"
        case .recordingChunk: return "Recording Chunk"
        case .transcript: return "Transcript"
        case .roomScan: return "Room Scan"
        }
    }
}

struct VisitTimelineEntry: Identifiable, Equatable {
    let id: UUID
    let capturedAt: Date
    let kind: VisitTimelineEntryKind
    let title: String
    let detail: String
    let roomID: UUID?
    let componentID: UUID?
    let evidenceID: UUID?
    let recordingID: UUID?
    let transcriptID: UUID?
    let reviewStatus: ReviewStatus?
}

extension Visit {
    var evidenceTimelineEntries: [EvidenceTimelineEntry] {
        evidenceTimelineEntries(componentID: nil)
    }

    func evidenceTimelineEntries(componentID requestedComponentID: UUID?) -> [EvidenceTimelineEntry] {
        let componentEntries = components
            .filter { component in
                requestedComponentID == nil || component.id == requestedComponentID
            }
            .flatMap { component in
                component.evidence.map { evidence in
                    EvidenceTimelineEntry(
                        id: evidence.id,
                        capturedAt: evidence.createdAt,
                        evidenceType: component.liveCaptureEvidenceKind?.title ?? evidence.kind.title,
                        componentID: component.id,
                        componentTitle: component.liveCaptureTitle,
                        spatialContext: component.spatialContext?.displaySummary,
                        reviewStatus: evidence.reviewStatus,
                        isMerged: repositoryState == .merged
                    )
                }
            }

        let roomEntries: [EvidenceTimelineEntry]
        if requestedComponentID == nil {
            roomEntries = rooms.flatMap { room in
                room.evidence.map { evidence in
                    EvidenceTimelineEntry(
                        id: evidence.id,
                        capturedAt: evidence.createdAt,
                        evidenceType: evidence.kind.title,
                        componentID: nil,
                        componentTitle: room.name,
                        spatialContext: room.spatialPlacement.anchorID,
                        reviewStatus: evidence.reviewStatus,
                        isMerged: repositoryState == .merged
                    )
                }
            }
        } else {
            roomEntries = []
        }

        return (componentEntries + roomEntries)
            .sorted { lhs, rhs in
                if lhs.capturedAt == rhs.capturedAt {
                    return lhs.componentTitle < rhs.componentTitle
                }
                return lhs.capturedAt > rhs.capturedAt
            }
    }

    var unifiedTimelineEntries: [VisitTimelineEntry] {
        var entries: [VisitTimelineEntry] = []

        entries.append(
            contentsOf: rooms.map { room in
                VisitTimelineEntry(
                    id: room.id,
                    capturedAt: createdAt,
                    kind: .roomScan,
                    title: VisitTimelineEntryKind.roomScan.title,
                    detail: room.name,
                    roomID: room.id,
                    componentID: nil,
                    evidenceID: nil,
                    recordingID: nil,
                    transcriptID: nil,
                    reviewStatus: room.reviewStatus
                )
            }
        )

        entries.append(
            contentsOf: rooms.flatMap { room in
                room.evidence.map { evidence in
                    makeTimelineEntry(
                        from: evidence,
                        capturedAt: evidence.createdAt,
                        detail: room.name,
                        roomID: room.id,
                        componentID: nil
                    )
                }
            }
        )

        entries.append(
            contentsOf: components.flatMap { component in
                component.evidence.map { evidence in
                    let liveKind = component.liveCaptureEvidenceKind
                    return makeTimelineEntry(
                        from: evidence,
                        capturedAt: evidence.createdAt,
                        detail: component.spatialContext.map { "\(component.liveCaptureTitle) - \($0.displaySummary)" } ?? component.liveCaptureTitle,
                        roomID: nil,
                        componentID: component.id,
                        titleOverride: liveKind?.title,
                        kindOverride: liveKind?.timelineKind
                    )
                }
            }
        )

        entries.append(
            contentsOf: recordings.map { recording in
                VisitTimelineEntry(
                    id: recording.id,
                    capturedAt: recording.startedAt,
                    kind: .recordingChunk,
                    title: recording.displayName,
                    detail: recording.status.title,
                    roomID: nil,
                    componentID: nil,
                    evidenceID: nil,
                    recordingID: recording.id,
                    transcriptID: nil,
                    reviewStatus: nil
                )
            }
        )

        entries.append(
            contentsOf: transcripts.map { transcript in
                VisitTimelineEntry(
                    id: transcript.id,
                    capturedAt: transcript.createdAt,
                    kind: .transcript,
                    title: VisitTimelineEntryKind.transcript.title,
                    detail: transcript.source.localFileName.map { "\(transcript.status.title) - \($0)" } ?? transcript.status.title,
                    roomID: nil,
                    componentID: nil,
                    evidenceID: nil,
                    recordingID: transcript.source.recordingID,
                    transcriptID: transcript.id,
                    reviewStatus: nil
                )
            }
        )

        return entries.sorted { lhs, rhs in
            if lhs.capturedAt == rhs.capturedAt {
                return lhs.title < rhs.title
            }
            return lhs.capturedAt < rhs.capturedAt
        }
    }

    private func makeTimelineEntry(
        from evidence: Evidence,
        capturedAt: Date,
        detail: String,
        roomID: UUID?,
        componentID: UUID?,
        titleOverride: String? = nil,
        kindOverride: VisitTimelineEntryKind? = nil
    ) -> VisitTimelineEntry {
        let kind: VisitTimelineEntryKind
        switch evidence.kind {
        case .photo:
            kind = .photo
        case .voiceNote:
            kind = .voiceNote
        case .textNote:
            kind = .note
        }

        return VisitTimelineEntry(
            id: evidence.id,
            capturedAt: capturedAt,
            kind: kindOverride ?? kind,
            title: titleOverride ?? (kindOverride ?? kind).title,
            detail: detail,
            roomID: roomID,
            componentID: componentID,
            evidenceID: evidence.id,
            recordingID: nil,
            transcriptID: nil,
            reviewStatus: evidence.reviewStatus
        )
    }
}

private extension LiveCaptureEvidenceKind {
    var timelineKind: VisitTimelineEntryKind {
        switch self {
        case .photo: return .photo
        case .mark: return .mark
        case .safety: return .safety
        }
    }
}
