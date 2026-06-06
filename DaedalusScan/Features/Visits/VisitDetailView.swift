import SwiftUI

struct VisitDetailView: View {
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID

    @State private var isPresentingRoomAlert = false
    @State private var isPresentingSummary = false
    @State private var isPresentingShareSheet = false
    @State private var shareURL: URL?
    @State private var roomName = ""

    var body: some View {
        if let visit = viewModel.visit(id: visitID) {
            let sections = viewModel.sectionList(for: visitID)
            List {
                captureAtAGlanceSection(visit: visit, sections: sections)
                systemContextSection(visit: visit)
                surveyModeSection(visit: visit, sections: sections)
                roomsSection(visit: visit)
                quickActionsSection
                needsReviewSection(visit: visit)
                visitMetadataSection(visit: visit)
            }
            .navigationTitle(visit.reference)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Summary") {
                        isPresentingSummary = true
                    }
                }
            }
            .navigationDestination(isPresented: $isPresentingSummary) {
                VisitSummaryView(visit: visit)
            }
            .sheet(isPresented: $isPresentingShareSheet) {
                if let url = shareURL {
                    ActivityView(url: url)
                }
            }
            .alert("Add Room", isPresented: $isPresentingRoomAlert) {
                TextField("Room name", text: $roomName)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    viewModel.addRoom(to: visitID, named: roomName)
                }
            } message: {
                Text("Rooms capture optional room-level photo, voice, text, and radiator evidence.")
            }
        } else {
            Text("Visit not found")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func captureAtAGlanceSection(visit: Visit, sections: [CaptureSection]) -> some View {
        let totalEvidence = visit.rooms.reduce(0) { $0 + $1.evidence.count }
            + visit.components.reduce(0) { $0 + $1.evidence.count }
        let requiredSections = sections.filter(\.isRequired)
        let completedRequired = requiredSections.filter { section in
            isSectionComplete(kind: section.kind, visit: visit)
        }.count

        Section {
            if requiredSections.isEmpty {
                LabeledContent("Section guidance", value: "All sections shown")
            } else {
                LabeledContent("Required complete", value: "\(completedRequired) / \(requiredSections.count)")
            }
            LabeledContent("Evidence items", value: "\(totalEvidence)")
            LabeledContent("Rooms", value: "\(visit.rooms.count)")
        } header: {
            Text("Capture Overview")
        }
    }

    @ViewBuilder
    private func systemContextSection(visit: Visit) -> some View {
        Section("System Context") {
            Picker(
                "Capture mode",
                selection: Binding(
                    get: { visit.captureMode },
                    set: { viewModel.setCaptureMode($0, for: visitID) }
                )
            ) {
                ForEach(CaptureMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            Picker(
                "Current system",
                selection: Binding(
                    get: { visit.currentSystemType },
                    set: { viewModel.setCurrentSystemType($0, for: visitID) }
                )
            ) {
                ForEach(HeatingSystemType.allCases, id: \.self) { system in
                    Text(system.title).tag(system)
                }
            }

            Picker(
                "Proposed system",
                selection: Binding(
                    get: { visit.proposedSystemType },
                    set: { viewModel.setProposedSystemType($0, for: visitID) }
                )
            ) {
                ForEach(HeatingSystemType.allCases, id: \.self) { system in
                    Text(system.title).tag(system)
                }
            }

            TextField(
                "Customer/site notes",
                text: Binding(
                    get: { visit.notes },
                    set: { viewModel.setVisitNotes($0, for: visitID) }
                ),
                axis: .vertical
            )
            .lineLimit(2...4)
        }
    }

    @ViewBuilder
    private func surveyModeSection(visit: Visit, sections: [CaptureSection]) -> some View {
        Section {
            ForEach(sections, id: \.kind.id) { section in
                NavigationLink {
                    SurveySectionCaptureView(
                        viewModel: viewModel,
                        visitID: visitID,
                        kind: section.kind
                    )
                } label: {
                    surveyRow(kind: section.kind, visit: visit, isRequired: section.isRequired)
                }
            }
        } header: {
            Text("System Capture")
        } footer: {
            if sections.allSatisfy({ !$0.isRequired }) {
                Text("Unknown system type: all sections shown as guidance-required, not mandatory.")
            }
        }
    }

    @ViewBuilder
    private func roomsSection(visit: Visit) -> some View {
        Section {
            if visit.rooms.isEmpty {
                Text("No rooms captured")
                    .foregroundStyle(.secondary)
            }
            ForEach(visit.rooms) { room in
                NavigationLink(room.name) {
                    RoomDetailView(viewModel: viewModel, visitID: visitID, roomID: room.id)
                }
            }
            Button("Add Room") {
                roomName = ""
                isPresentingRoomAlert = true
            }
        } header: {
            Text("Rooms")
        } footer: {
            Text("Capture room name, photos, voice notes, text notes, and optional radiator evidence.")
        }
    }

    private var quickActionsSection: some View {
        Section {
            Button {
                isPresentingSummary = true
            } label: {
                Label("Open Summary", systemImage: "list.bullet.clipboard")
            }
            Button {
                if let url = viewModel.makeExportTempURL(for: visitID) {
                    shareURL = url
                    isPresentingShareSheet = true
                }
            } label: {
                Label("Share / Save .daedalusscan", systemImage: "square.and.arrow.up")
            }
        } header: {
            Text("Quick Actions")
        }
    }

    @ViewBuilder
    private func needsReviewSection(visit: Visit) -> some View {
        let needsReviewCount = visit.rooms.filter { $0.reviewStatus == .needsReview }.count
            + visit.components.filter { $0.reviewStatus == .needsReview }.count
        if needsReviewCount > 0 {
            Section {
                NavigationLink {
                    VisitSummaryView(visit: visit)
                } label: {
                    Label(
                        "\(needsReviewCount) item\(needsReviewCount == 1 ? "" : "s") queued for review",
                        systemImage: "eye"
                    )
                    .foregroundStyle(.orange)
                }
            }
        }
    }

    @ViewBuilder
    private func visitMetadataSection(visit: Visit) -> some View {
        Section {
            LabeledContent("Reference", value: visit.reference)
            LabeledContent("Twin Layers", value: "System · House · Home")
            LabeledContent("Created") {
                Text(visit.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            if !visit.customerName.isEmpty {
                LabeledContent("Customer", value: visit.customerName)
            }
            if !visit.addressLine.isEmpty {
                LabeledContent("Address", value: visit.addressLine)
            }
            if !visit.postcode.isEmpty {
                LabeledContent("Postcode", value: visit.postcode)
            }
            if let engineer = visit.engineerName {
                LabeledContent("Engineer", value: engineer)
            }
            if let date = visit.appointmentDate {
                LabeledContent("Appointment") {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                }
            }
        } header: {
            Text("Visit")
        }
    }

    @ViewBuilder
    private func surveyRow(kind: SystemComponentKind, visit: Visit, isRequired: Bool) -> some View {
        let sectionStatus = visit.captureMode == .current
            ? (visit.sectionStatuses[kind] ?? .notChecked)
            : (visit.proposedSectionStatuses[kind] ?? .notChecked)
        let evidenceCount = visit.components
            .filter { $0.kind == kind && $0.captureMode == visit.captureMode }
            .reduce(0) { $0 + $1.evidence.count }
        let isComplete = isSectionComplete(kind: kind, visit: visit)

        HStack {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isComplete ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.surveyTitle)
                Text("\(sectionStatus.title) · \(evidenceCount) evidence")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !isRequired {
                Text("Guidance")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func isSectionComplete(kind: SystemComponentKind, visit: Visit) -> Bool {
        let sectionStatus = visit.captureMode == .current
            ? (visit.sectionStatuses[kind] ?? .notChecked)
            : (visit.proposedSectionStatuses[kind] ?? .notChecked)
        let hasStatus = sectionStatus != .notChecked
        let hasEvidence = visit.components
            .filter { $0.kind == kind && $0.captureMode == visit.captureMode }
            .contains { !$0.evidence.isEmpty }
        return hasStatus || hasEvidence
    }
}
