import DaedalusContracts
import SwiftUI

struct ComponentDetailView: View {
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID
    let componentID: UUID

    @StateObject private var recorder = VoiceNoteRecorder()
    @State private var isPresentingCamera = false
    @State private var isPresentingTextNote = false
    @State private var textNoteContent = ""

    var body: some View {
        Group {
            if let component = viewModel.component(visitID: visitID, componentID: componentID) {
                List {
                    Section("Component") {
                        LabeledContent("Type", value: component.kind.title)
                        if !component.name.isEmpty {
                            LabeledContent("Name", value: component.name)
                        }
                        if !component.manufacturer.isEmpty {
                            LabeledContent("Manufacturer", value: component.manufacturer)
                        }
                        if !component.model.isEmpty {
                            LabeledContent("Model", value: component.model)
                        }
                        if !component.notes.isEmpty {
                            Text(component.notes)
                        }
                    }

                    Section("Evidence") {
                        if component.evidence.isEmpty {
                            Text("No evidence captured yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(component.evidence) { evidence in
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
                .navigationTitle(component.kind.title)
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
                        viewModel.attachPhoto(data: imageData, to: componentID, in: visitID)
                    }
                }
                .sheet(isPresented: $isPresentingTextNote) {
                    ComponentTextNoteSheet(text: $textNoteContent) {
                        viewModel.attachTextNote(text: textNoteContent, to: componentID, in: visitID)
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
                Text("Component not found")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func toggleVoiceRecording() {
        if recorder.isRecording {
            if let url = recorder.stopRecording() {
                viewModel.attachVoiceNote(from: url, to: componentID, in: visitID)
            }
        } else if let url = viewModel.prepareVoiceNoteURL(for: componentID, in: visitID) {
            recorder.startRecording(to: url)
        }
    }
}

private struct ComponentTextNoteSheet: View {
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
