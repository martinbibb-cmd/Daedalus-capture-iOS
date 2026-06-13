import SwiftUI

struct CaptureReviewWorkspaceRow: Identifiable, Equatable {
    let id: UUID
    let title: String
    let detail: String
    let capturedAt: Date
    let status: String?
    let systemImage: String
}

struct CaptureReviewWorkspaceSummary: Equatable {
    var recordings: [CaptureReviewWorkspaceRow]
    var transcripts: [CaptureReviewWorkspaceRow]
    var observations: [CaptureReviewWorkspaceRow]
    var photos: [CaptureReviewWorkspaceRow]

    var isEmpty: Bool {
        recordings.isEmpty && transcripts.isEmpty && observations.isEmpty && photos.isEmpty
    }
}

extension Visit {
    var captureReviewWorkspaceSummary: CaptureReviewWorkspaceSummary {
        CaptureReviewWorkspaceSummary(
            recordings: recordings
                .sorted { $0.sequenceNumber < $1.sequenceNumber }
                .map { recording in
                    CaptureReviewWorkspaceRow(
                        id: recording.id,
                        title: recording.displayName,
                        detail: recording.localFileName,
                        capturedAt: recording.startedAt,
                        status: recording.status.title,
                        systemImage: "waveform"
                    )
                },
            transcripts: transcripts
                .sorted { $0.createdAt < $1.createdAt }
                .map { transcript in
                    CaptureReviewWorkspaceRow(
                        id: transcript.id,
                        title: "Transcript",
                        detail: transcript.rawTranscript.isEmpty ? transcript.source.localFileName ?? "Recording transcript" : transcript.rawTranscript,
                        capturedAt: transcript.createdAt,
                        status: transcript.status.title,
                        systemImage: "text.quote"
                    )
                },
            observations: observationReviewRows,
            photos: photoReviewRows
        )
    }

    private var observationReviewRows: [CaptureReviewWorkspaceRow] {
        let roomRows = rooms.map { room in
            CaptureReviewWorkspaceRow(
                id: room.id,
                title: room.name,
                detail: "Area observation",
                capturedAt: createdAt,
                status: room.reviewStatus?.title,
                systemImage: "square.dashed"
            )
        }

        let componentRows = components.map { component in
            CaptureReviewWorkspaceRow(
                id: component.id,
                title: component.canonicalSubtype.title,
                detail: component.spatialContext?.displaySummary ?? component.spatialPlacement.captureState.title,
                capturedAt: createdAt,
                status: component.reviewStatus?.title,
                systemImage: "cube"
            )
        }

        let nonPhotoEvidenceRows = rooms.flatMap { room in
            room.evidence
                .filter { $0.kind != .photo }
                .map { evidence in
                    evidenceReviewRow(
                        evidence,
                        title: evidence.kind.title,
                        detail: room.name,
                        systemImage: evidence.kind.systemImage
                    )
                }
        } + components.flatMap { component in
            component.evidence
                .filter { $0.kind != .photo }
                .map { evidence in
                    evidenceReviewRow(
                        evidence,
                        title: evidence.kind.title,
                        detail: component.canonicalSubtype.title,
                        systemImage: evidence.kind.systemImage
                    )
                }
        }

        return (roomRows + componentRows + nonPhotoEvidenceRows)
            .sorted { lhs, rhs in
                if lhs.capturedAt == rhs.capturedAt {
                    return lhs.title < rhs.title
                }
                return lhs.capturedAt < rhs.capturedAt
            }
    }

    private var photoReviewRows: [CaptureReviewWorkspaceRow] {
        let roomPhotos = rooms.flatMap { room in
            room.evidence
                .filter { $0.kind == .photo }
                .map { evidence in
                    evidenceReviewRow(
                        evidence,
                        title: EvidenceKind.photo.title,
                        detail: room.name,
                        systemImage: EvidenceKind.photo.systemImage
                    )
                }
        }

        let componentPhotos = components.flatMap { component in
            component.evidence
                .filter { $0.kind == .photo }
                .map { evidence in
                    evidenceReviewRow(
                        evidence,
                        title: EvidenceKind.photo.title,
                        detail: component.canonicalSubtype.title,
                        systemImage: EvidenceKind.photo.systemImage
                    )
                }
        }

        return (roomPhotos + componentPhotos)
            .sorted { lhs, rhs in
                if lhs.capturedAt == rhs.capturedAt {
                    return lhs.detail < rhs.detail
                }
                return lhs.capturedAt < rhs.capturedAt
            }
    }

    private func evidenceReviewRow(
        _ evidence: Evidence,
        title: String,
        detail: String,
        systemImage: String
    ) -> CaptureReviewWorkspaceRow {
        CaptureReviewWorkspaceRow(
            id: evidence.id,
            title: title,
            detail: detail,
            capturedAt: evidence.createdAt,
            status: evidence.reviewStatus?.title,
            systemImage: systemImage
        )
    }
}

struct CaptureReviewWorkspaceView: View {
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID

    var body: some View {
        if let visit = viewModel.visit(id: visitID) {
            let summary = visit.captureReviewWorkspaceSummary
            List {
                if summary.isEmpty {
                    ContentUnavailableView("No capture items", systemImage: "tray")
                } else {
                    reviewSection("Recordings", rows: summary.recordings)
                    reviewSection("Transcripts", rows: summary.transcripts)
                    reviewSection("Observations", rows: summary.observations)
                    reviewSection("Photos", rows: summary.photos)
                }
            }
            .navigationTitle("Capture Review")
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("Property Twin not found", systemImage: "exclamationmark.triangle")
        }
    }

    @ViewBuilder
    private func reviewSection(_ title: String, rows: [CaptureReviewWorkspaceRow]) -> some View {
        if !rows.isEmpty {
            Section(title) {
                ForEach(rows) { row in
                    CaptureReviewWorkspaceRowView(row: row)
                }
            }
        }
    }
}

private struct CaptureReviewWorkspaceRowView: View {
    let row: CaptureReviewWorkspaceRow

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: row.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(row.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if let status = row.status {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(row.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                Text(row.capturedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
