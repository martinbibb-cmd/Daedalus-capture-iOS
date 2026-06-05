import SwiftUI

struct VisitDetailView: View {
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID

    @State private var isPresentingRoomAlert = false
    @State private var isPresentingSummary = false
    @State private var isPresentingShareSheet = false
    @State private var shareURL: URL?
    @State private var roomName = ""

    private let surveySections: [SystemComponentKind] = [
        .boiler,
        .flue,
        .controls,
        .cylinder,
        .feedAndExpansion,
        .gasMeter,
        .radiator,
        .pump,
        .pipework
    ]

    var body: some View {
        if let visit = viewModel.visit(id: visitID) {
            List {
                captureAtAGlanceSection(visit: visit)
                surveyModeSection(visit: visit)
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
                Text("Add rooms for optional room-by-room evidence capture.")
            }
        } else {
            Text("Visit not found")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func captureAtAGlanceSection(visit: Visit) -> some View {
        let totalEvidence = visit.rooms.reduce(0) { $0 + $1.evidence.count }
            + visit.components.reduce(0) { $0 + $1.evidence.count }
        let completedSections = surveySections.filter { kind in
            isSectionComplete(kind: kind, visit: visit)
        }.count

        Section("Survey Mode") {
            LabeledContent("Sections complete", value: "\(completedSections) / \(surveySections.count)")
            LabeledContent("Evidence items", value: "\(totalEvidence)")
            LabeledContent("Rooms", value: "\(visit.rooms.count)")
        }
    }

    @ViewBuilder
    private func surveyModeSection(visit: Visit) -> some View {
        Section("Start Survey") {
            ForEach(surveySections, id: \.id) { kind in
                NavigationLink {
                    SurveySectionCaptureView(viewModel: viewModel, visitID: visitID, kind: kind)
                } label: {
                    surveyRow(kind: kind, visit: visit)
                }
            }
        }
    }

    @ViewBuilder
    private func roomsSection(visit: Visit) -> some View {
        Section("Rooms") {
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
        } footer: {
            Text("Rooms are optional in survey mode and can be captured after system evidence.")
        }
    }

    private var quickActionsSection: some View {
        Section("Quick Actions") {
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
                Label("Export Visit Package", systemImage: "square.and.arrow.up")
            }
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
        Section("Visit") {
            LabeledContent("Reference", value: visit.reference)
            LabeledContent("Twin", value: visit.twinKind.title)
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
            if !visit.notes.isEmpty {
                LabeledContent("Notes", value: visit.notes)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func surveyRow(kind: SystemComponentKind, visit: Visit) -> some View {
        let sectionStatus = visit.sectionStatuses[kind] ?? .notChecked
        let evidenceCount = visit.components
            .filter { $0.kind == kind }
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
        }
    }

    private func isSectionComplete(kind: SystemComponentKind, visit: Visit) -> Bool {
        let hasStatus = (visit.sectionStatuses[kind] ?? .notChecked) != .notChecked
        let hasEvidence = visit.components
            .filter { $0.kind == kind }
            .contains { !$0.evidence.isEmpty }
        return hasStatus || hasEvidence
    }
}
