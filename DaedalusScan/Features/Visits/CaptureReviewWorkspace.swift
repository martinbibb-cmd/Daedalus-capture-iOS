import SwiftUI
import UIKit

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

struct CaptureReviewCard: Identifiable, Equatable {
    let id: UUID
    let componentID: UUID
    let evidenceID: UUID?
    let markerType: LiveCaptureEvidenceKind
    let capturedAt: Date
    let photoFileName: String?
    let transcriptExcerpt: String
    let suggestedLabel: String
    let reviewedLabel: String
    let anchorStatus: String
    let status: ReviewStatus?
    let confidence: String

    var requiresAttention: Bool {
        markerType == .safety && (status == .unreviewed || status == .needsAttention)
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
            observations: rooms.map { room in
                CaptureReviewWorkspaceRow(
                    id: room.id,
                    title: room.name,
                    detail: "Area observation",
                    capturedAt: createdAt,
                    status: room.reviewStatus?.title,
                    systemImage: "square.dashed"
                )
            } + components.flatMap { component in
                component.evidence
                    .filter { $0.kind != .photo }
                    .map { evidence in
                        CaptureReviewWorkspaceRow(
                            id: evidence.id,
                            title: evidence.kind.title,
                            detail: component.liveCaptureTitle,
                            capturedAt: evidence.createdAt,
                            status: evidence.reviewStatus?.title,
                            systemImage: evidence.kind.systemImage
                        )
                    }
            },
            photos: components.flatMap { component in
                component.evidence
                    .filter { $0.kind == .photo }
                    .map { evidence in
                        CaptureReviewWorkspaceRow(
                            id: evidence.id,
                            title: EvidenceKind.photo.title,
                            detail: component.liveCaptureTitle,
                            capturedAt: evidence.createdAt,
                            status: evidence.reviewStatus?.title,
                            systemImage: EvidenceKind.photo.systemImage
                        )
                    }
            }
        )
    }

    var captureReviewCards: [CaptureReviewCard] {
        liveCaptureEvidenceComponents.compactMap { component in
            guard let markerType = component.liveCaptureEvidenceKind else { return nil }
            let primaryEvidence = component.evidence.sorted { $0.createdAt < $1.createdAt }.first
            return CaptureReviewCard(
                id: component.id,
                componentID: component.id,
                evidenceID: primaryEvidence?.id,
                markerType: markerType,
                capturedAt: primaryEvidence?.createdAt ?? component.createdAtFallback,
                photoFileName: component.evidence.first(where: { $0.kind == .photo })?.localFileName,
                transcriptExcerpt: component.componentAttributes["transcriptSnippet"] ?? "",
                suggestedLabel: component.suggestedCaptureLabel,
                reviewedLabel: component.reviewedCaptureLabel,
                anchorStatus: component.spatialPlacement.captureState == .anchored ? "anchored" : "geometry pending",
                status: component.reviewStatus,
                confidence: component.spatialPlacement.confidence.title
            )
        }
        .sorted { lhs, rhs in
            if lhs.requiresAttention != rhs.requiresAttention {
                return lhs.requiresAttention
            }
            return lhs.capturedAt < rhs.capturedAt
        }
    }

    private var reviewedPackageReadyCount: Int {
        reviewedCaptureEvidenceComponents.count
    }

    var captureReviewSummaryText: String {
        "\(reviewedPackageReadyCount) reviewed / \(liveCaptureEvidenceComponents.count) raw"
    }
}

private extension SystemComponent {
    var createdAtFallback: Date {
        evidence.map(\.createdAt).min() ?? Date()
    }
}

struct CaptureReviewWorkspaceView: View {
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID

    @State private var changeTarget: CaptureReviewCard?
    @State private var isPresentingShareSheet = false
    @State private var shareURL: URL?

    var body: some View {
        if let visit = viewModel.visit(id: visitID) {
            let cards = visit.captureReviewCards
            List {
                Section {
                    HStack {
                        Label(visit.captureReviewSummaryText, systemImage: "checklist.checked")
                        Spacer()
                        if visit.hasBlockingCaptureReviewItems {
                            Text("Attention needed")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red)
                        }
                    }
                } footer: {
                    Text("Review confirms Capture evidence before export or handoff. Suggestions are weak until confirmed or changed.")
                }

                if cards.isEmpty {
                    ContentUnavailableView("No capture evidence", systemImage: "tray")
                } else {
                    Section("Evidence") {
                        ForEach(cards) { card in
                            CaptureReviewCardView(
                                card: card,
                                thumbnailURL: card.photoFileName.flatMap { viewModel.evidenceFileURL(localFileName: $0) },
                                onConfirm: {
                                    viewModel.setCaptureReviewDecision(
                                        .confirmed,
                                        componentID: card.componentID,
                                        visitID: visitID,
                                        reviewedLabel: card.suggestedLabel
                                    )
                                },
                                onChange: { changeTarget = card },
                                onIgnore: {
                                    viewModel.setCaptureReviewDecision(.ignored, componentID: card.componentID, visitID: visitID)
                                },
                                onNeedsAttention: {
                                    viewModel.setCaptureReviewDecision(.needsAttention, componentID: card.componentID, visitID: visitID)
                                }
                            )
                        }
                    }
                }

                Section {
                    Button {
                        if let url = viewModel.makeReviewedExportTempURL(for: visitID) {
                            shareURL = url
                            isPresentingShareSheet = true
                        }
                    } label: {
                        Label("Create Reviewed Capture Package", systemImage: "shippingbox")
                    }
                    .disabled(cards.isEmpty || visit.hasBlockingCaptureReviewItems)
                } footer: {
                    Text("The package keeps raw evidence and review decisions. Confirmed or changed evidence is marked for reviewed handoff.")
                }
            }
            .navigationTitle("Review Capture")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.refreshCaptureReviewSuggestions(for: visitID)
            }
            .sheet(item: $changeTarget) { card in
                CaptureReviewChangeSheet(card: card) { label in
                    viewModel.setCaptureReviewDecision(
                        .changed,
                        componentID: card.componentID,
                        visitID: visitID,
                        reviewedLabel: label
                    )
                }
            }
            .sheet(isPresented: $isPresentingShareSheet) {
                if let shareURL {
                    ActivityView(url: shareURL)
                }
            }
        } else {
            ContentUnavailableView("Property Twin not found", systemImage: "exclamationmark.triangle")
        }
    }
}

private struct CaptureReviewCardView: View {
    let card: CaptureReviewCard
    let thumbnailURL: URL?
    let onConfirm: () -> Void
    let onChange: () -> Void
    let onIgnore: () -> Void
    let onNeedsAttention: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                PhotoThumbnail(url: thumbnailURL, markerType: card.markerType)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(card.markerType.title, systemImage: systemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(card.markerType == .safety ? .red : .primary)
                        Spacer()
                        Text(card.status?.title ?? ReviewStatus.unreviewed.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(statusColor)
                    }

                    Text(card.suggestedLabel)
                        .font(.headline)

                    if !card.transcriptExcerpt.isEmpty {
                        Text(card.transcriptExcerpt)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    } else {
                        Text("No transcript snippet available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        Label(card.anchorStatus, systemImage: "location")
                        Label(card.confidence, systemImage: "scope")
                        Text(card.capturedAt.formatted(date: .omitted, time: .shortened))
                            .monospacedDigit()
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }

            if card.requiresAttention {
                Label("Safety marker requires review before handoff", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }

            HStack(spacing: 8) {
                Button("Confirm", action: onConfirm)
                    .buttonStyle(.borderedProminent)
                Button("Change", action: onChange)
                    .buttonStyle(.bordered)
                Button("Ignore", action: onIgnore)
                    .buttonStyle(.bordered)
                if card.markerType == .safety {
                    Button("Needs attention", action: onNeedsAttention)
                        .buttonStyle(.bordered)
                        .tint(.red)
                }
            }
            .font(.caption.weight(.semibold))
        }
        .padding(.vertical, 8)
    }

    private var systemImage: String {
        switch card.markerType {
        case .photo: return "photo"
        case .voice: return "waveform"
        case .mark: return "mappin.and.ellipse"
        case .safety: return "exclamationmark.triangle.fill"
        case .measurement: return "ruler"
        }
    }

    private var statusColor: Color {
        switch card.status {
        case .confirmed, .changed:
            return .green
        case .ignored:
            return .secondary
        case .needsAttention:
            return .red
        default:
            return .orange
        }
    }
}

private struct PhotoThumbnail: View {
    let url: URL?
    let markerType: LiveCaptureEvidenceKind

    var body: some View {
        Group {
            if let url,
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: placeholderSystemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(markerType == .safety ? .red : .secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.tertiarySystemGroupedBackground))
            }
        }
        .frame(width: 74, height: 74)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var placeholderSystemImage: String {
        switch markerType {
        case .photo:
            return "photo"
        case .voice:
            return "waveform"
        case .mark:
            return "mappin.and.ellipse"
        case .safety:
            return "exclamationmark.triangle.fill"
        case .measurement:
            return "ruler"
        }
    }
}

private struct CaptureReviewChangeSheet: View {
    @Environment(\.dismiss) private var dismiss

    let card: CaptureReviewCard
    let onSave: (String) -> Void

    @State private var label: String

    init(card: CaptureReviewCard, onSave: @escaping (String) -> Void) {
        self.card = card
        self.onSave = onSave
        _label = State(initialValue: card.reviewedLabel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reviewed Label") {
                    TextField("Label", text: $label)
                        .textInputAutocapitalization(.words)
                }

                Section("Original Suggestion") {
                    Text(card.suggestedLabel)
                    if !card.transcriptExcerpt.isEmpty {
                        Text(card.transcriptExcerpt)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Change Evidence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(label.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
