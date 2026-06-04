import DaedalusContracts
import SwiftUI

struct RoomDetailView: View {
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID
    let roomID: UUID

    @StateObject private var recorder = VoiceNoteRecorder()
    @State private var isPresentingCamera = false
    @State private var isPresentingTextNote = false
    @State private var textNoteContent = ""

    var body: some View {
        Group {
            if let room = viewModel.room(visitID: visitID, roomID: roomID) {
                List {
                    Section("Review") {
                        Picker(
                            "Status",
                            selection: Binding(
                                get: { room.reviewStatus },
                                set: { viewModel.setRoomReviewStatus($0, roomID: roomID, visitID: visitID) }
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
                                get: { room.reviewNotes ?? "" },
                                set: { viewModel.setRoomReviewNotes($0, roomID: roomID, visitID: visitID) }
                            ),
                            axis: .vertical
                        )
                        .lineLimit(2...4)
                    }

                    Section("Survey") {
                        ForEach(DaedalusCatalog.defaultSurvey) { question in
                            SurveyQuestionRow(
                                question: question,
                                response: viewModel.response(for: question.key, visitID: visitID, roomID: roomID)
                            ) { updatedResponse in
                                viewModel.updateResponse(updatedResponse, for: question.key, visitID: visitID, roomID: roomID)
                            } onReviewStatusChange: { status in
                                viewModel.setSurveyResponseReviewStatus(
                                    status,
                                    questionKey: question.key,
                                    roomID: roomID,
                                    visitID: visitID
                                )
                            } onReviewNotesChange: { notes in
                                viewModel.setSurveyResponseReviewNotes(
                                    notes,
                                    questionKey: question.key,
                                    roomID: roomID,
                                    visitID: visitID
                                )
                            }
                        }
                    }

                    Section("Evidence") {
                        if room.evidence.isEmpty {
                            Text("No evidence captured yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(room.evidence) { evidence in
                                EvidenceReviewRow(
                                    evidence: evidence,
                                    onStatusChange: { status in
                                        viewModel.setRoomEvidenceReviewStatus(
                                            status,
                                            evidenceID: evidence.id,
                                            roomID: roomID,
                                            visitID: visitID
                                        )
                                    },
                                    onNotesChange: { notes in
                                        viewModel.setRoomEvidenceReviewNotes(
                                            notes,
                                            evidenceID: evidence.id,
                                            roomID: roomID,
                                            visitID: visitID
                                        )
                                    }
                                )
                            }
                        }
                    }
                }
                .navigationTitle(room.name)
                .safeAreaInset(edge: .bottom) {
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
                            Label(recorder.isRecording ? "Stop Note" : "Voice Note", systemImage: recorder.isRecording ? "stop.circle" : "waveform")
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
                .sheet(isPresented: $isPresentingCamera) {
                    CameraCaptureView { imageData in
                        viewModel.attachPhoto(data: imageData, to: roomID, in: visitID)
                    }
                }
                .sheet(isPresented: $isPresentingTextNote) {
                    TextNoteSheet(text: $textNoteContent) {
                        viewModel.attachTextNote(text: textNoteContent, to: roomID, in: visitID)
                    }
                }
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

private struct SurveyQuestionRow: View {
    let question: SurveyQuestion
    let response: SurveyResponse
    let onChange: (SurveyResponse) -> Void
    let onReviewStatusChange: (ReviewStatus?) -> Void
    let onReviewNotesChange: (String) -> Void

    @State private var numericText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.label)
                .font(.headline)

            switch question.kind {
            case .boolean:
                Toggle(
                    "Answered",
                    isOn: Binding(
                        get: { response.booleanValue ?? false },
                        set: { onChange(SurveyResponse(booleanValue: $0)) }
                    )
                )
            case .singleChoice:
                Picker(
                    question.label,
                    selection: Binding(
                        get: { response.selectedValue ?? question.allowedValues.first ?? "" },
                        set: { onChange(SurveyResponse(selectedValue: $0)) }
                    )
                ) {
                    ForEach(question.allowedValues, id: \.self) { value in
                        Text(value).tag(value)
                    }
                }
                .pickerStyle(.segmented)
            case .numeric:
                TextField(
                    "Value",
                    text: Binding(
                        get: { response.numericValue.map { String(Int($0)) } ?? numericText },
                        set: { newValue in
                            numericText = newValue
                            onChange(SurveyResponse(numericValue: Double(newValue)))
                        }
                    )
                )
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
            }

            Picker(
                "Review",
                selection: Binding(
                    get: { response.reviewStatus },
                    set: onReviewStatusChange
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
                    get: { response.reviewNotes ?? "" },
                    set: onReviewNotesChange
                ),
                axis: .vertical
            )
            .lineLimit(2...3)
        }
        .padding(.vertical, 4)
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
