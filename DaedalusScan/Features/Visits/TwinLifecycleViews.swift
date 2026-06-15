import SwiftUI

struct PropertyTwinHomeView: View {
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID
    var onRequestLeave: (() -> Void)?
    @State private var isPresentingCaptureLite = false
    @State private var showSurveyRecord = false

    var body: some View {
        if let visit = viewModel.visit(id: visitID) {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(visit.reference)
                            .font(.title2.weight(.semibold))
                        HStack(spacing: 10) {
                            Label("Version \(visit.twinVersion)", systemImage: "number")
                            Label(visit.repositoryState.title, systemImage: "arrow.triangle.branch")
                            Label(visit.captureSessionStatus.title, systemImage: visit.captureSessionStatus.systemImage)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Text(lastMergedText(for: visit))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Property Twin")
                }

                Section {
                    NavigationLink {
                        LiveCaptureView(viewModel: viewModel, visitID: visitID)
                    } label: {
                        SurveyPrimaryActionRow(visit: visit)
                    }
                } header: {
                    Text("Survey")
                } footer: {
                    Text("Walk, talk, capture, then review before merge.")
                }

                Section {
                    NavigationLink {
                        StageModeView(viewModel: viewModel, visitID: visitID, showsResumeSurveyLink: true)
                    } label: {
                        Label("Review Survey", systemImage: "list.bullet.rectangle")
                    }

                    NavigationLink {
                        MergeModeView(viewModel: viewModel, visitID: visitID)
                    } label: {
                        Label("Merge Twin", systemImage: "arrow.triangle.merge")
                    }
                } header: {
                    Text("Finish")
                }

                Section {
                    DisclosureGroup(isExpanded: $showSurveyRecord) {
                        NavigationLink {
                            TwinOverviewView(viewModel: viewModel, visitID: visitID)
                        } label: {
                            Label("Twin Overview", systemImage: "map")
                        }

                        NavigationLink {
                            EvidenceTimelineView(viewModel: viewModel, visitID: visitID)
                        } label: {
                            Label("Evidence Log", systemImage: "clock")
                        }

                        NavigationLink {
                            AttachEvidenceSheet(viewModel: viewModel, visitID: visitID)
                        } label: {
                            Label("Attach Existing Evidence", systemImage: "paperclip")
                        }

                        Button {
                            isPresentingCaptureLite = true
                        } label: {
                            Label("Snapshot Fallback", systemImage: "camera")
                        }

                        Button {
                            viewModel.requestPullTwin(for: visitID)
                        } label: {
                            Label("Refresh Working Twin", systemImage: "arrow.down.circle")
                        }
                    } label: {
                        Label("Survey Record", systemImage: "folder")
                    }
                } header: {
                    Text("More")
                }

                Section {
                    TwinLifecycleStrip(visit: visit)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                } header: {
                    Text("Status")
                }
            }
            .navigationTitle("Property Twin")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isPresentingCaptureLite) {
                CaptureLiteSheet(areas: visit.areas) { request in
                    _ = viewModel.addCaptureLiteEvidenceCapture(
                        to: visitID,
                        subtype: request.subtype,
                        areaID: request.areaID,
                        photoData: request.includePicture ? Data([0x00]) : nil,
                        voiceNoteText: request.voiceNoteText,
                        photoEvidenceLabel: request.photoEvidenceLabel
                    )
                }
            }
            .navigationBarBackButtonHidden(onRequestLeave != nil)
            .toolbar {
                if let onRequestLeave {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            onRequestLeave()
                        } label: {
                            Label("Property Twins", systemImage: "chevron.left")
                        }
                    }
                }
            }
        } else {
            ContentUnavailableView("Property Twin not found", systemImage: "exclamationmark.triangle")
        }
    }

    private func lastMergedText(for visit: Visit) -> String {
        guard let lastMergedAt = visit.lastMergedAt else {
            return "Last Merged: Never"
        }
        return "Last Merged: \(lastMergedAt.formatted(date: .abbreviated, time: .omitted))"
    }

}

private struct SurveyPrimaryActionRow: View {
    let visit: Visit

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.16))
                    .frame(width: 48, height: 48)
                Image(systemName: "figure.walk.motion")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(primaryTitle)
                    .font(.headline.weight(.semibold))
                Text("Continuous space and audio capture")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !warnings.isEmpty {
                    Text(warnings.joined(separator: " · "))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var primaryTitle: String {
        switch visit.captureSessionStatus {
        case .hasUnreviewedEvidence:
            return "Continue Survey"
        case .readyToMerge, .merged:
            return "Open Survey"
        default:
            return "Start Survey"
        }
    }

    private var warnings: [String] {
        var output: [String] = []
        if visit.hasUnreviewedEvidence {
            output.append("review pending")
        }
        if visit.hasUnmergedLocalWork {
            output.append("merge pending")
        }
        return output
    }
}

private struct CaptureLiteRequest {
    let subtype: SystemComponentSubtype
    let areaID: UUID?
    let includePicture: Bool
    let voiceNoteText: String
    let photoEvidenceLabel: String
}

private struct CaptureLiteSheet: View {
    @Environment(\.dismiss) private var dismiss
    let areas: [Room]
    let onCapture: (CaptureLiteRequest) -> Void

    @State private var subtype: SystemComponentSubtype = .unknownHeatSource
    @State private var areaID: UUID?
    @State private var includePicture = true
    @State private var voiceNoteText = ""
    @State private var photoEvidenceLabel = "Picture captured in Capture Lite."

    var body: some View {
        NavigationStack {
            Form {
                Section("Capture Lite") {
                    Picker("Component Type", selection: $subtype) {
                        ForEach(SystemComponentSubtype.allCases) { subtype in
                            Text(subtype.title).tag(subtype)
                        }
                    }

                    Picker("Area / Location", selection: $areaID) {
                        Text("Spatial capture").tag(Optional<UUID>.none)
                        ForEach(areas) { area in
                            Text(area.name).tag(Optional(area.id))
                        }
                    }
                }

                Section("Evidence") {
                    Toggle("Picture", isOn: $includePicture)
                    TextField("Picture label", text: $photoEvidenceLabel, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Voice Note", text: $voiceNoteText, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Capture Lite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Capture") {
                        onCapture(
                            CaptureLiteRequest(
                                subtype: subtype,
                                areaID: areaID,
                                includePicture: includePicture,
                                voiceNoteText: voiceNoteText,
                                photoEvidenceLabel: photoEvidenceLabel
                            )
                        )
                        dismiss()
                    }
                    .disabled(!includePicture && voiceNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct TwinLifecycleStrip: View {
    let visit: Visit

    private let stages: [TwinLifecycleStage] = [
        .pull,
        .capture,
        .commit,
        .stage,
        .clarify,
        .recapture,
        .confirm,
        .merge
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(stages, id: \.self) { stage in
                    Label(stage.title, systemImage: icon(for: stage))
                        .font(.caption.weight(stage == visit.lifecycleStage ? .semibold : .regular))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(stage == visit.lifecycleStage ? Color.accentColor.opacity(0.16) : Color(.tertiarySystemGroupedBackground))
                        .foregroundStyle(stage == visit.lifecycleStage ? Color.accentColor : Color.secondary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 2)
        }
        .accessibilityLabel("Twin lifecycle stage \(visit.lifecycleStage.title)")
    }

    private func icon(for stage: TwinLifecycleStage) -> String {
        switch stage {
        case .pull: return "arrow.down.circle"
        case .capture: return "camera.viewfinder"
        case .commit: return "square.and.arrow.down"
        case .stage: return "list.bullet.rectangle"
        case .clarify: return "questionmark.circle"
        case .recapture: return "arrow.clockwise"
        case .confirm: return "checkmark.seal"
        case .merge: return "arrow.triangle.merge"
        }
    }
}

struct TwinOverviewView: View {
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID
    @State private var markerFilter: ComponentMarkerFilter = .all

    var body: some View {
        if let visit = viewModel.visit(id: visitID) {
            let markers = visit.componentMarkers(matching: markerFilter)
            List {
                Section {
                    LabeledContent("Property Twin", value: visit.reference)
                    LabeledContent("State", value: visit.repositoryState.title)
                    LabeledContent("Lifecycle", value: visit.lifecycleStage.title)
                } header: {
                    Text("Property Twin")
                }

                Section {
                    TwinCountRow(title: "Areas", count: visit.areas.count, systemImage: "square.split.bottomrightquarter")
                    TwinCountRow(title: "Geometry evidence", count: visit.areas.reduce(0) { $0 + $1.evidence.count }, systemImage: "photo")
                } header: {
                    Text("House Twin")
                } footer: {
                    Text("Rooms label the captured geometry and boundaries.")
                }

                Section {
                    ForEach(SystemComponentCategory.allCases.filter { $0 != .unknown }, id: \.id) { category in
                        TwinCountRow(
                            title: category.title,
                            count: visit.components.filter { $0.canonicalCategory == category }.count,
                            systemImage: "cube"
                        )
                    }
                    TwinCountRow(title: "Relationships", count: visit.relationships.count, systemImage: "point.3.connected.trianglepath.dotted")
                } header: {
                    Text("System Twin")
                } footer: {
                    Text("Components are primary. Relationships can be added over time.")
                }

                Section {
                    Picker("Markers", selection: $markerFilter) {
                        ForEach(ComponentMarkerFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    if markers.isEmpty {
                        Text("No component markers captured.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(markers) { marker in
                            NavigationLink {
                                ComponentDetailView(
                                    viewModel: viewModel,
                                    visitID: visitID,
                                    componentID: marker.componentID
                                )
                            } label: {
                                ComponentMarkerRow(marker: marker)
                            }
                        }
                    }
                } header: {
                    Text("Floor Plan Markers")
                }

                Section {
                    if visit.notes.isEmpty {
                        Text("No home observations captured.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(visit.notes)
                    }
                    TwinCountRow(title: "Service points", count: visit.servicePointObservations.count, systemImage: "faucet")
                    TwinCountRow(title: "Water observations", count: visit.waterSupplyObservations.count, systemImage: "drop")
                } header: {
                    Text("Home Twin")
                } footer: {
                    Text("Capture records context and constraints without generating advice.")
                }
            }
            .navigationTitle("Twin Overview")
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("Property Twin not found", systemImage: "exclamationmark.triangle")
        }
    }
}

struct StageModeView: View {
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID
    var showsResumeSurveyLink = false
    var onResumeSurvey: (() -> Void)?

    var body: some View {
        if let visit = viewModel.visit(id: visitID) {
            List {
                if showsResumeSurveyLink || onResumeSurvey != nil {
                    Section {
                        if let onResumeSurvey {
                            Button {
                                onResumeSurvey()
                            } label: {
                                Label("Resume Survey", systemImage: "figure.walk.motion")
                            }
                        } else {
                            NavigationLink {
                                LiveCaptureView(viewModel: viewModel, visitID: visitID)
                            } label: {
                                Label("Resume Survey", systemImage: "figure.walk.motion")
                            }
                        }

                        Text("Review is a checkpoint. Resume keeps the survey open so you can collect more evidence before merge.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Survey")
                    }
                }

                Section {
                    TwinCountRow(title: "Added areas", count: visit.areas.count, systemImage: "square.dashed")
                    TwinCountRow(title: "Added components", count: visit.components.count, systemImage: "cube")
                    TwinCountRow(title: "Evidence items", count: evidenceCount(for: visit), systemImage: "paperclip")
                    TwinCountRow(title: "Relationships", count: visit.relationships.count, systemImage: "point.3.connected.trianglepath.dotted")
                } header: {
                    Text("Proposed Changes")
                }

                evidenceByComponentSections(for: visit)

                Section {
                    ForEach(reviewItems(for: visit), id: \.self) { item in
                        Label(item, systemImage: "exclamationmark.circle")
                    }
                    if reviewItems(for: visit).isEmpty {
                        Label("No clarification items", systemImage: "checkmark.circle")
                    }
                } header: {
                    Text("Clarify")
                }

                Section {
                    Button {
                        viewModel.confirmCapturedEvidence(for: visitID)
                    } label: {
                        Label("Confirm Captured Evidence", systemImage: "checkmark.seal")
                    }
                    .disabled(evidenceItems(for: visit).isEmpty && reviewItems(for: visit).isEmpty)

                    Button {
                        viewModel.advanceLifecycle(.commit, for: visitID)
                    } label: {
                        Label("Commit Local Change Set", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        viewModel.advanceLifecycle(.clarify, for: visitID)
                    } label: {
                        Label("Clarify", systemImage: "questionmark.circle")
                    }

                    Button {
                        viewModel.advanceLifecycle(.confirm, for: visitID)
                    } label: {
                        Label("Confirm", systemImage: "checkmark.seal")
                    }
                } header: {
                    Text("Review")
                }
            }
            .navigationTitle("Review Survey")
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("Property Twin not found", systemImage: "exclamationmark.triangle")
        }
    }

    private func evidenceCount(for visit: Visit) -> Int {
        visit.areas.reduce(0) { $0 + $1.evidence.count } +
            visit.components.reduce(0) { $0 + $1.evidence.count }
    }

    private func reviewItems(for visit: Visit) -> [String] {
        let rooms = visit.areas
            .filter { $0.reviewStatus == .needsReview }
            .map { "Area: \($0.name)" }
        let components = visit.components
            .filter { $0.reviewStatus == .needsReview }
            .map { "Component: \($0.canonicalSubtype.title)" }
        let roomEvidence = visit.areas.flatMap { room in
            room.evidence
                .filter { $0.reviewStatus == .needsReview }
                .map { "Evidence: \(room.name) - \($0.kind.title)" }
        }
        let componentEvidence = visit.components.flatMap { component in
            component.evidence
                .filter { $0.reviewStatus == .needsReview }
                .map { "Evidence: \(component.canonicalSubtype.title) - \($0.kind.title)" }
        }
        return rooms + components + roomEvidence + componentEvidence
    }

    private func evidenceItems(for visit: Visit) -> [String] {
        let roomEvidence = visit.areas.flatMap { room in
            room.evidence.map { "\(room.name) - \($0.kind.title) - \($0.reviewStatus?.title ?? "Not set")" }
        }
        let componentEvidence = visit.components.flatMap { component in
            component.evidence.map { "\(component.canonicalSubtype.title) - \($0.kind.title) - \($0.reviewStatus?.title ?? "Not set")" }
        }
        return roomEvidence + componentEvidence
    }

    @ViewBuilder
    private func evidenceByComponentSections(for visit: Visit) -> some View {
        let groups = visit.captureReviewEvidenceGroups

        if groups.isEmpty {
            Section {
                Label("No evidence captured", systemImage: "paperclip")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Evidence")
            }
        } else {
            ForEach(groups) { group in
                Section {
                    ForEach(Array(group.cards.enumerated()), id: \.offset) { _, card in
                        EvidenceCardView(
                            title: card.title,
                            systemImage: systemImage(for: card.title),
                            detail: card.detail,
                            reviewStatus: card.reviewStatus,
                            capturedAt: card.capturedAt,
                            spatialContext: card.spatialContext
                        )
                    }
                } header: {
                    Text(group.title)
                }
            }
        }
    }

    private func systemImage(for evidenceTitle: String) -> String {
        switch evidenceTitle {
        case "Component Type":
            return "cube"
        case "Area / Location":
            return "location"
        case "Geometry":
            return "scope"
        default:
            return EvidenceKind.allCases.first { $0.title == evidenceTitle }?.systemImage ?? "paperclip"
        }
    }
}

struct MergeModeView: View {
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID

    var body: some View {
        if let visit = viewModel.visit(id: visitID) {
            let summary = visit.mergeSummary
            List {
                Section {
                    LabeledContent("Property Twin", value: visit.reference)
                    LabeledContent("Current state", value: visit.repositoryState.title)
                    LabeledContent("Version", value: "\(summary.currentVersion) -> \(summary.nextVersion)")
                } header: {
                    Text("Merge Twin")
                } footer: {
                    Text("Merge Twin updates the authoritative twin from confirmed captured reality.")
                }

                Section {
                    LabeledContent("Added components", value: "\(summary.addedComponents)")
                    LabeledContent("Edited evidence", value: "\(summary.editedEvidence)")
                    LabeledContent("Deleted evidence", value: "\(summary.deletedEvidence)")
                    LabeledContent("Confirmed evidence", value: "\(summary.confirmedEvidence)")
                    LabeledContent("Still needs review", value: "\(summary.needsReviewEvidence)")
                } header: {
                    Text("Merge Summary")
                }

                Section {
                    if summary.hasUnreviewedEvidence {
                        Label("Evidence still needs review", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    } else {
                        Label("No evidence review warnings", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                    if summary.confirmedEvidence + summary.needsReviewEvidence == 0 {
                        Label("Property Twin has no evidence", systemImage: "paperclip.badge.ellipsis")
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("Warnings")
                }

                Section {
                    Button {
                        viewModel.requestMergeTwin(for: visitID)
                    } label: {
                        Label("Merge Twin", systemImage: "arrow.triangle.merge")
                    }
                }
            }
            .navigationTitle("Merge Twin")
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("Property Twin not found", systemImage: "exclamationmark.triangle")
        }
    }
}

struct EvidenceTimelineView: View {
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID
    var componentID: UUID?

    var body: some View {
        if let visit = viewModel.visit(id: visitID) {
            let entries = visit.evidenceTimelineEntries(componentID: componentID)
            List {
                if entries.isEmpty {
                    ContentUnavailableView("No evidence captured", systemImage: "clock")
                } else {
                    ForEach(entries) { entry in
                        EvidenceTimelineRow(entry: entry)
                    }
                }
            }
            .navigationTitle("Evidence Timeline")
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("Property Twin not found", systemImage: "exclamationmark.triangle")
        }
    }
}

private struct EvidenceTimelineRow: View {
    let entry: EvidenceTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Label(entry.evidenceType, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(entry.reviewStatus?.title ?? "Captured")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(entry.reviewStatus == .needsReview ? .orange : .secondary)
            }

            Text(entry.componentTitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let spatialContext = entry.spatialContext, !spatialContext.isEmpty {
                Label(spatialContext, systemImage: "location")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(entry.capturedAt.formatted(date: .abbreviated, time: .shortened))
                Spacer()
                Text(entry.isMerged ? "Merged" : "Working Twin")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var systemImage: String {
        switch entry.evidenceType {
        case EvidenceKind.photo.title: return EvidenceKind.photo.systemImage
        case EvidenceKind.voiceNote.title: return EvidenceKind.voiceNote.systemImage
        case EvidenceKind.textNote.title: return EvidenceKind.textNote.systemImage
        default: return "paperclip"
        }
    }
}

private struct TwinCountRow: View {
    let title: String
    let count: Int
    let systemImage: String

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(count == 0 ? "Unknown" : "\(count)")
                .foregroundStyle(.secondary)
        }
    }
}

private struct ComponentMarkerRow: View {
    let marker: ComponentMarker

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.16))
                    .frame(width: 36, height: 36)
                Image(systemName: marker.systemImage)
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(marker.title)
                    .font(.subheadline.weight(.semibold))
                Text(marker.areaLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(marker.positionLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(marker.reviewStatus?.title ?? "Captured")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(marker.reviewStatus == .needsReview ? .orange : .secondary)
                Text(marker.mergeStateTitle)
                    .font(.caption2)
                    .foregroundStyle(marker.isMerged ? .green : .secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
