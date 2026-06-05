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

                    Section("Review") {
                        Picker(
                            "Status",
                            selection: Binding(
                                get: { component.reviewStatus },
                                set: { viewModel.setComponentReviewStatus($0, componentID: componentID, visitID: visitID) }
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
                                get: { component.reviewNotes ?? "" },
                                set: { viewModel.setComponentReviewNotes($0, componentID: componentID, visitID: visitID) }
                            ),
                            axis: .vertical
                        )
                        .lineLimit(2...4)
                    }

                    Section("Captured details") {
                        ForEach(component.kind.attributeFields) { field in
                            ComponentAttributeFieldRow(
                                field: field,
                                value: component.componentAttributes[field.key] ?? "",
                                onChange: { newValue in
                                    viewModel.updateComponentAttribute(newValue, for: field.key, componentID: componentID, visitID: visitID)
                                }
                            )
                        }
                    }

                    Section("Evidence") {
                        if component.evidence.isEmpty {
                            Text("No evidence captured yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(component.evidence) { evidence in
                                EvidenceReviewRow(
                                    evidence: evidence,
                                    onStatusChange: { status in
                                        viewModel.setComponentEvidenceReviewStatus(
                                            status,
                                            evidenceID: evidence.id,
                                            componentID: componentID,
                                            visitID: visitID
                                        )
                                    },
                                    onNotesChange: { notes in
                                        viewModel.setComponentEvidenceReviewNotes(
                                            notes,
                                            evidenceID: evidence.id,
                                            componentID: componentID,
                                            visitID: visitID
                                        )
                                    }
                                )
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
                        viewModel.attachPhoto(data: imageData, toComponent: componentID, in: visitID)
                    }
                }
                .sheet(isPresented: $isPresentingTextNote) {
                    ComponentTextNoteSheet(text: $textNoteContent) {
                        viewModel.attachTextNoteToComponent(text: textNoteContent, to: componentID, in: visitID)
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
                viewModel.attachVoiceNoteToComponent(from: url, to: componentID, in: visitID)
            }
        } else if let url = viewModel.prepareComponentVoiceNoteURL(for: componentID, in: visitID) {
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

private struct ComponentAttributeFieldRow: View {
    let field: ComponentAttributeField
    let value: String
    let onChange: (String) -> Void

    var body: some View {
        switch field.kind {
        case .text:
            TextField(
                field.label,
                text: Binding(
                    get: { value },
                    set: onChange
                )
            )
        case .multiline:
            TextField(
                field.label,
                text: Binding(
                    get: { value },
                    set: onChange
                ),
                axis: .vertical
            )
            .lineLimit(3...6)
        case let .singleChoice(options):
            Picker(
                field.label,
                selection: Binding(
                    get: { value.isEmpty ? (options.first ?? "") : value },
                    set: onChange
                )
            ) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
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
