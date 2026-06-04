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
                    Section("Survey") {
                        ForEach(DaedalusCatalog.defaultSurvey) { question in
                            SurveyQuestionRow(
                                question: question,
                                response: viewModel.response(for: question.key, visitID: visitID, roomID: roomID)
                            ) { updatedResponse in
                                viewModel.updateResponse(updatedResponse, for: question.key, visitID: visitID, roomID: roomID)
                            }
                        }
                    }

                    Section("Evidence") {
                        if room.evidence.isEmpty {
                            Text("No evidence captured yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(room.evidence) { evidence in
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
                viewModel.attachVoiceNote(from: url, to: roomID, in: visitID)
            }
        } else if let url = viewModel.prepareVoiceNoteURL(for: roomID, in: visitID) {
            recorder.startRecording(to: url)
        }
    }
}

private struct SurveyQuestionRow: View {
    let question: SurveyQuestion
    let response: SurveyResponse
    let onChange: (SurveyResponse) -> Void

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
