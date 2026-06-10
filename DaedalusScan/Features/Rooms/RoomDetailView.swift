import SwiftUI

struct RoomDetailView: View {
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID
    let roomID: UUID

    @StateObject private var recorder = VoiceNoteRecorder()
    @State private var isPresentingCamera = false
    @State private var isPresentingTextNote = false
    @State private var textNoteContent = ""

    var body: some View { mainContent }

    private var room: Room? {
        viewModel.room(visitID: visitID, roomID: roomID)
    }

    private var mainContent: some View {
        Group {
            if let room {
                List {
                    spatialSection
                    roomNotesSection
                    reviewSection
                    evidenceSection
                }
                .navigationTitle(room.name)
                .safeAreaInset(edge: .bottom) { bottomCaptureBar }
                .sheet(isPresented: $isPresentingCamera) { cameraSheet }
                .sheet(isPresented: $isPresentingTextNote) { textNoteSheet }
                .onChange(of: recorder.errorMessage) { _, newValue in
                    if let newValue {
                        viewModel.errorMessage = newValue
                    }
                }
                .onDisappear {
                    if recorder.isRecording {
                        _ = recorder.stopRecording()
                    }
                }
            } else {
                Text("Room not found")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var roomNotesSection: some View {
        Section {
            TextField(
                "Area notes",
                text: roomNotesBinding,
                axis: .vertical
            )
            .lineLimit(2...5)
        } header: {
            Text("Area Notes")
        }
    }

    @ViewBuilder
    private var spatialSection: some View {
        if let room {
            Section {
                LabeledContent("State", value: room.spatialPlacement.captureState.title)
                LabeledContent("Confidence", value: room.spatialPlacement.confidence.title)
                LabeledContent("Anchor", value: room.spatialPlacement.anchorID ?? "None")
                if let position = room.spatialPlacement.approximatePosition {
                    LabeledContent(
                        "Approximate position",
                        value: String(format: "%.2f, %.2f, %.2f", position.x, position.y, position.z)
                    )
                }
            } header: {
                Text("Spatial Capture")
            } footer: {
                Text("Spatial metadata is exported with the visit package, including fallback states when anchoring is unavailable.")
            }
        }
    }

    private var reviewSection: some View {
        Section {
            Picker("Status", selection: roomReviewStatusBinding) {
                Text("Not set").tag(Optional<ReviewStatus>.none)
                ForEach(ReviewStatus.allCases, id: \.self) { status in
                    Text(status.title).tag(Optional(status))
                }
            }
            .pickerStyle(.menu)
            TextField(
                "Review notes",
                text: roomReviewNotesBinding,
                axis: .vertical
            )
            .lineLimit(2...4)
        } header: {
            Text("Review")
        }
    }

    private var evidenceSection: some View {
        Section {
            if let room {
                if room.evidence.isEmpty {
                    Text("No evidence captured yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(room.evidence) { evidence in
                        EvidenceReviewRow(
                            evidence: evidence,
                            onStatusChange: { status in
                                setRoomEvidenceReviewStatus(status, evidenceID: evidence.id)
                            },
                            onNotesChange: { notes in
                                setRoomEvidenceReviewNotes(notes, evidenceID: evidence.id)
                            }
                        )
                    }
                }
            }
        } header: {
            Text("Evidence")
        } footer: {
            Text("Optional radiator/emitter evidence can be captured here.")
        }
    }

    private var bottomCaptureBar: some View {
        HStack {
            Button {
                isPresentingCamera = true
            } label: {
                Label("Photo", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                toggleVoiceRecording()
            } label: {
                Label(
                    recorder.isRecording ? "Stop Note" : "Voice Note",
                    systemImage: recorder.isRecording ? "stop.circle" : "waveform"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                textNoteContent = ""
                isPresentingTextNote = true
            } label: {
                Label("Text Note", systemImage: "text.alignleft")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.bar)
    }

    private var textNoteSheet: some View {
        TextNoteSheet(text: $textNoteContent) {
            viewModel.attachTextNote(text: textNoteContent, to: roomID, in: visitID)
        }
    }

    private var cameraSheet: some View {
        CameraCaptureView { imageData in
            viewModel.attachPhoto(data: imageData, to: roomID, in: visitID)
        }
    }

    private var roomNotesBinding: Binding<String> {
        Binding(
            get: { room?.notes ?? "" },
            set: { viewModel.setRoomNotes($0, roomID: roomID, visitID: visitID) }
        )
    }

    private var roomReviewStatusBinding: Binding<ReviewStatus?> {
        Binding(
            get: { room?.reviewStatus },
            set: { viewModel.setRoomReviewStatus($0, roomID: roomID, visitID: visitID) }
        )
    }

    private var roomReviewNotesBinding: Binding<String> {
        Binding(
            get: { room?.reviewNotes ?? "" },
            set: { viewModel.setRoomReviewNotes($0, roomID: roomID, visitID: visitID) }
        )
    }

    private func setRoomEvidenceReviewStatus(_ status: ReviewStatus?, evidenceID: UUID) {
        viewModel.setRoomEvidenceReviewStatus(
            status,
            evidenceID: evidenceID,
            roomID: roomID,
            visitID: visitID
        )
    }

    private func setRoomEvidenceReviewNotes(_ notes: String, evidenceID: UUID) {
        viewModel.setRoomEvidenceReviewNotes(
            notes,
            evidenceID: evidenceID,
            roomID: roomID,
            visitID: visitID
        )
    }

    private func toggleVoiceRecording() {
        if recorder.isRecording {
            if let url = recorder.stopRecording() {
                viewModel.attachVoiceNoteToRoom(from: url, to: roomID, in: visitID)
            }
        } else if let url = viewModel.prepareRoomVoiceNoteURL(for: roomID, in: visitID) {
            recorder.startRecording(to: url)
        }
    }
}

private struct EvidenceReviewRow: View {
    let evidence: Evidence
    let onStatusChange: (ReviewStatus?) -> Void
    let onNotesChange: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    evidence.kind == .photo ? "Photo" : evidence.kind == .voiceNote ? "Voice Note" : "Text Note",
                    systemImage: evidence.kind == .photo ? "camera" : evidence.kind == .voiceNote ? "waveform" : "text.alignleft"
                )
                Spacer()
                Text(evidence.localFileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Picker(
                "Review",
                selection: Binding(
                    get: { evidence.reviewStatus },
                    set: onStatusChange
                )
            ) {
                Text("Not set").tag(Optional<ReviewStatus>.none)
                ForEach(ReviewStatus.allCases, id: \.self) { status in
                    Text(status.title).tag(Optional(status))
                }
            }
            .pickerStyle(.menu)
            TextField(
                "Review notes",
                text: Binding(
                    get: { evidence.reviewNotes ?? "" },
                    set: onNotesChange
                ),
                axis: .vertical
            )
            .lineLimit(2...3)
        }
        .padding(.vertical, 4)
    }
}

private struct TextNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .padding()
                .navigationTitle("Text Note")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onSave()
                            dismiss()
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
    }
}
