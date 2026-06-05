import SwiftUI

struct SurveySectionCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID
    let kind: SystemComponentKind

    @StateObject private var recorder = VoiceNoteRecorder()
    @State private var isPresentingCamera = false
    @State private var isPresentingTextNote = false
    @State private var textNoteContent = ""
    @State private var activeComponentID: UUID?
    @State private var isShowingAdvancedDetails = false

    private var visit: Visit? {
        viewModel.visit(id: visitID)
    }

    private var components: [SystemComponent] {
        visit?.components.filter { $0.kind == kind } ?? []
    }

    private var evidenceCount: Int {
        components.reduce(0) { $0 + $1.evidence.count }
    }

    private var statusBinding: Binding<SectionStatus> {
        Binding<SectionStatus>(
            get: { visit?.sectionStatuses[kind] ?? .notChecked },
            set: { viewModel.setSectionStatus($0, for: kind, visitID: visitID) }
        )
    }

    private var reviewLaterBinding: Binding<Bool> {
        Binding<Bool>(
            get: { components.contains(where: { $0.reviewStatus == .needsReview }) },
            set: { viewModel.setSectionReviewLater($0, for: kind, visitID: visitID) }
        )
    }

    var body: some View {
        Group {
            if visit != nil {
                List {
                    Section("Capture") {
                        Picker("Status", selection: statusBinding) {
                            ForEach(SectionStatus.allCases, id: \.self) { status in
                                Text(status.title).tag(status)
                            }
                        }
                        .pickerStyle(.menu)
                        LabeledContent("Evidence", value: "\(evidenceCount)")
                    }

                    Section("Review Later") {
                        Toggle("Flag for post-capture review", isOn: reviewLaterBinding)
                    } footer: {
                        Text("Use this to queue transcription and structured extraction after field capture.")
                    }

                    Section {
                        DisclosureGroup("Advanced Details", isExpanded: $isShowingAdvancedDetails) {
                            if components.isEmpty {
                                Text("No section components yet.")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 6)
                            }
                            ForEach(Array(components.enumerated()), id: \.element.id) { index, component in
                                NavigationLink("Component \(index + 1)") {
                                    ComponentDetailView(viewModel: viewModel, visitID: visitID, componentID: component.id)
                                }
                            }
                            Button("Add Another \(kind.surveyTitle)") {
                                viewModel.addComponent(to: visitID, kind: kind, name: "", manufacturer: "", model: "", notes: "")
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .navigationTitle(kind.surveyTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        Button {
                            activeComponentID = viewModel.ensureComponent(for: kind, visitID: visitID)
                            if activeComponentID != nil {
                                isPresentingCamera = true
                            }
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
                            activeComponentID = viewModel.ensureComponent(for: kind, visitID: visitID)
                            if activeComponentID != nil {
                                textNoteContent = ""
                                isPresentingTextNote = true
                            }
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
                        if let componentID = activeComponentID ?? viewModel.ensureComponent(for: kind, visitID: visitID) {
                            viewModel.attachPhoto(data: imageData, toComponent: componentID, in: visitID)
                        }
                    }
                }
                .sheet(isPresented: $isPresentingTextNote) {
                    SurveySectionTextNoteSheet(text: $textNoteContent) {
                        if let componentID = activeComponentID ?? viewModel.ensureComponent(for: kind, visitID: visitID) {
                            viewModel.attachTextNoteToComponent(text: textNoteContent, to: componentID, in: visitID)
                        }
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
                Text("Section not found")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func toggleVoiceRecording() {
        if recorder.isRecording {
            if let componentID = activeComponentID, let url = recorder.stopRecording() {
                viewModel.attachVoiceNoteToComponent(from: url, to: componentID, in: visitID)
            }
            activeComponentID = nil
            return
        }

        guard let componentID = viewModel.ensureComponent(for: kind, visitID: visitID),
              let url = viewModel.prepareComponentVoiceNoteURL(for: componentID, in: visitID) else {
            return
        }
        activeComponentID = componentID
        recorder.startRecording(to: url)
    }
}

private struct SurveySectionTextNoteSheet: View {
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
