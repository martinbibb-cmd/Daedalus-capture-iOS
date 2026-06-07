import SwiftUI

struct ComponentDetailView: View {
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID
    let componentID: UUID

    @StateObject private var recorder = VoiceNoteRecorder()
    @State private var isPresentingCamera = false
    @State private var isPresentingTextNote = false
    @State private var textNoteContent = ""
    @State private var relationshipType: SpatialRelationshipType = .connectedTo
    @State private var relationshipTargetMode: RelationshipTargetMode = .component
    @State private var targetComponentID: UUID?
    @State private var targetAreaID: UUID?

    var body: some View {
        Group {
            if let component = viewModel.component(visitID: visitID, componentID: componentID) {
                List {
                    spatialSection(component: component)
                    Section("Component") {
                        LabeledContent("Category", value: component.canonicalCategory.title)
                        LabeledContent("Type", value: component.canonicalSubtype.title)
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

                                relationshipsSection(component: component)
                            )
                        }

                        @ViewBuilder
                        private func relationshipsSection(component: SystemComponent) -> some View {
                            let visit = viewModel.visit(id: visitID)
                            let relationships = viewModel.relationships(for: visitID, sourceComponentID: componentID)

                            Section("Relationships") {
                                if relationships.isEmpty {
                                    Text("No observed relationships yet.")
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(relationships) { relationship in
                                        HStack {
                                            Text(relationship.relationship.title)
                                            Spacer()
                                            Text(relationshipTargetLabel(relationship: relationship, visit: visit))
                                                .foregroundStyle(.secondary)
                                            Button(role: .destructive) {
                                                viewModel.removeRelationship(visitID: visitID, relationshipID: relationship.id)
                                            } label: {
                                                Image(systemName: "trash")
                                            }
                                            .buttonStyle(.borderless)
                                        }
                                    }
                                }

                                Picker("Type", selection: $relationshipType) {
                                    ForEach(SpatialRelationshipType.allCases) { relationship in
                                        Text(relationship.title).tag(relationship)
                                    }
                                }

                                Picker("Target", selection: $relationshipTargetMode) {
                                    Text("Component").tag(RelationshipTargetMode.component)
                                    Text("Area").tag(RelationshipTargetMode.area)
                                }
                                .pickerStyle(.segmented)

                                if relationshipTargetMode == .component {
                                    let currentCaptureMode = visit?.captureMode
                                    Picker("Component", selection: $targetComponentID) {
                                        Text("Select").tag(Optional<UUID>.none)
                                        ForEach((visit?.components ?? []).filter { candidate in
                                            candidate.id != componentID && (currentCaptureMode == nil || candidate.captureMode == currentCaptureMode)
                                        }) { candidate in
                                            Text(candidate.canonicalSubtype.title).tag(Optional(candidate.id))
                                        }
                                    }
                                } else {
                                    Picker("Area", selection: $targetAreaID) {
                                        Text("Select").tag(Optional<UUID>.none)
                                        ForEach(visit?.areas ?? []) { area in
                                            Text(area.name).tag(Optional(area.id))
                                        }
                                    }
                                }

                                Button("Add Relationship") {
                                    viewModel.addRelationship(
                                        visitID: visitID,
                                        sourceComponentID: componentID,
                                        relationship: relationshipType,
                                        targetComponentID: relationshipTargetMode == .component ? targetComponentID : nil,
                                        targetAreaID: relationshipTargetMode == .area ? targetAreaID : nil
                                    )
                                    targetComponentID = nil
                                    targetAreaID = nil
                                }
                                .disabled(relationshipTargetMode == .component ? targetComponentID == nil : targetAreaID == nil)
                            } footer: {
                                Text("Relationships are observed links only; no simulation is inferred.")
                            }
                        }

                        private func relationshipTargetLabel(relationship: SpatialRelationship, visit: Visit?) -> String {
                            if let componentID = relationship.targetComponentID,
                               let component = visit?.components.first(where: { $0.id == componentID }) {
                                return component.canonicalSubtype.title
                            }
                            if let areaID = relationship.targetAreaID,
                               let area = visit?.areas.first(where: { $0.id == areaID }) {
                                return area.name
                            }
                            return "Unknown"
                        }
                    }

                    private enum RelationshipTargetMode {
                        case component
                        case area
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

    @ViewBuilder
    private func spatialSection(component: SystemComponent) -> some View {
        Section("Spatial Capture") {
            LabeledContent("State", value: component.spatialPlacement.captureState.title)
            LabeledContent("Confidence", value: component.spatialPlacement.confidence.title)
            LabeledContent("Anchor", value: component.spatialPlacement.anchorID ?? "None")
            if let position = component.spatialPlacement.approximatePosition {
                LabeledContent(
                    "Approximate position",
                    value: "\(position.x, specifier: "%.2f"), \(position.y, specifier: "%.2f"), \(position.z, specifier: "%.2f")"
                )
            }
        } footer: {
            Text("Spatial objects remain exportable even when capture falls back to area-reference-only placement.")
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
