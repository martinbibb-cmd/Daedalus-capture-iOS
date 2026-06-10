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
    @State private var isPresentingBundleEditor = false
    @State private var isConfirmingBundleDelete = false

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
                            )
                        }
                    }

                    relationshipsSection(component: component)

                    Section("Evidence") {
                        EvidenceCardView(
                            title: "Component Type",
                            systemImage: "cube",
                            detail: component.componentAttributes["componentTypeEvidence"] ?? component.canonicalSubtype.title,
                            reviewStatus: component.evidenceBundleStatus,
                            capturedAt: nil,
                            spatialContext: component.spatialContext?.displaySummary
                        )

                        EvidenceCardView(
                            title: "Area / Location",
                            systemImage: "location",
                            detail: component.componentAttributes["areaEvidence"] ?? component.componentAttributes["location"] ?? component.spatialPlacement.captureState.title,
                            reviewStatus: component.evidenceBundleStatus,
                            capturedAt: nil,
                            spatialContext: component.spatialContext?.displaySummary
                        )

                        if let geometryEvidence = component.componentAttributes["geometryEvidence"] {
                            EvidenceCardView(
                                title: "Geometry",
                                systemImage: "scope",
                                detail: geometryEvidence,
                                reviewStatus: component.evidenceBundleStatus,
                                capturedAt: nil,
                                spatialContext: component.spatialContext?.displaySummary
                            )
                        }

                        if component.evidence.isEmpty {
                            Text("No picture or voice evidence captured yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(component.evidence) { evidence in
                                EvidenceReviewRow(
                                    component: component,
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

                        Button {
                            isPresentingBundleEditor = true
                        } label: {
                            Label("Edit Evidence Bundle", systemImage: "square.and.pencil")
                        }

                        NavigationLink {
                            EvidenceTimelineView(viewModel: viewModel, visitID: visitID, componentID: componentID)
                        } label: {
                            Label("Evidence Timeline", systemImage: "clock")
                        }

                        Button(role: .destructive) {
                            isConfirmingBundleDelete = true
                        } label: {
                            Label("Delete Evidence Bundle", systemImage: "trash")
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
                .sheet(isPresented: $isPresentingBundleEditor) {
                    EvidenceBundleEditSheet(
                        visit: viewModel.visit(id: visitID),
                        component: component,
                        onSave: { subtype, areaID, geometryID, approximatePositionLabel, voiceNoteTranscript, photoEvidenceLabel in
                            viewModel.updateEvidenceBundle(
                                componentID: componentID,
                                visitID: visitID,
                                subtype: subtype,
                                areaID: areaID,
                                geometryID: geometryID,
                                approximatePositionLabel: approximatePositionLabel,
                                voiceNoteTranscript: voiceNoteTranscript,
                                photoEvidenceLabel: photoEvidenceLabel
                            )
                        }
                    )
                }
                .confirmationDialog(
                    "Delete Evidence Bundle",
                    isPresented: $isConfirmingBundleDelete,
                    titleVisibility: .visible
                ) {
                    Button("Delete Evidence Bundle", role: .destructive) {
                        viewModel.deleteEvidenceBundle(componentID: componentID, visitID: visitID)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This removes the captured component evidence bundle from Review.")
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

    @ViewBuilder
    private func relationshipsSection(component: SystemComponent) -> some View {
        let visit = viewModel.visit(id: visitID)
        let relationships = viewModel.relationships(for: visitID, sourceComponentID: componentID)

        Section {
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
        } header: {
            Text("Relationships")
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
        Section {
            LabeledContent("State", value: component.spatialPlacement.captureState.title)
            LabeledContent("Confidence", value: component.spatialPlacement.confidence.title)
            LabeledContent("Anchor", value: component.spatialPlacement.anchorID ?? "None")
            if let position = component.spatialPlacement.approximatePosition {
                LabeledContent(
                    "Approximate position",
                    value: String(format: "%.2f, %.2f, %.2f", position.x, position.y, position.z)
                )
            }
        } header: {
            Text("Spatial Capture")
        } footer: {
            Text("Spatial objects remain exportable even when capture falls back to area-reference-only placement.")
        }
    }
}

private enum RelationshipTargetMode {
    case component
    case area
}

private struct EvidenceReviewRow: View {
    let component: SystemComponent
    let evidence: Evidence
    let onStatusChange: (ReviewStatus?) -> Void
    let onNotesChange: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            EvidenceCardView(
                title: evidence.kind.title,
                systemImage: evidence.kind.systemImage,
                    detail: component.displayDetail(for: evidence),
                    reviewStatus: evidence.reviewStatus,
                    capturedAt: evidence.createdAt,
                    spatialContext: nil
                )
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

private struct EvidenceBundleEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let visit: Visit?
    let component: SystemComponent
    let onSave: (SystemComponentSubtype, UUID?, String, String, String, String) -> Void

    @State private var subtype: SystemComponentSubtype
    @State private var areaID: UUID?
    @State private var geometryID: String
    @State private var approximatePositionLabel: String
    @State private var voiceNoteTranscript: String
    @State private var photoEvidenceLabel: String

    init(
        visit: Visit?,
        component: SystemComponent,
        onSave: @escaping (SystemComponentSubtype, UUID?, String, String, String, String) -> Void
    ) {
        self.visit = visit
        self.component = component
        self.onSave = onSave
        _subtype = State(initialValue: component.canonicalSubtype)
        let selectedAreaID = visit?.relationships.first {
            $0.sourceComponentID == component.id && $0.relationship == .containedIn && $0.targetAreaID != nil
        }?.targetAreaID
        _areaID = State(initialValue: selectedAreaID)
        _geometryID = State(initialValue: component.spatialContext?.geometryID ?? "")
        _approximatePositionLabel = State(initialValue: component.spatialContext?.approximatePositionLabel ?? "")
        _voiceNoteTranscript = State(initialValue: component.componentAttributes["voiceNoteTranscript"] ?? "")
        _photoEvidenceLabel = State(initialValue: component.componentAttributes["photoEvidenceLabel"] ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Evidence Bundle") {
                    Picker("Component Type", selection: $subtype) {
                        ForEach(SystemComponentSubtype.allCases) { subtype in
                            Text(subtype.title).tag(subtype)
                        }
                    }

                    Picker("Area / Location", selection: $areaID) {
                        Text("Spatial capture").tag(Optional<UUID>.none)
                        ForEach(visit?.areas ?? []) { area in
                            Text(area.name).tag(Optional(area.id))
                        }
                    }
                }

                Section("Spatial Context") {
                    TextField("Geometry ID", text: $geometryID)
                    TextField("Approximate position", text: $approximatePositionLabel)
                }

                Section("Notes") {
                    TextField("Voice Note", text: $voiceNoteTranscript, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Picture label", text: $photoEvidenceLabel, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Edit Evidence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(subtype, areaID, geometryID, approximatePositionLabel, voiceNoteTranscript, photoEvidenceLabel)
                        dismiss()
                    }
                }
            }
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
