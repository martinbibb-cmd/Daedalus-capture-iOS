import SwiftUI
import UIKit

public struct VisitListView: View {
    @ObservedObject var viewModel: VisitListViewModel

    public init(viewModel: VisitListViewModel) {
        self.viewModel = viewModel
    }

    @State private var isPresentingCreateVisit = false
    @State private var isPresentingImport = false
    @State private var isPresentingShareSheet = false
    @State private var shareURL: URL?
    @State private var searchText = ""
    @State private var navigationPath: [UUID] = []

    private var filteredVisits: [Visit] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return viewModel.visits }
        return viewModel.visits.filter { visit in
            visit.reference.lowercased().contains(query) ||
            visit.customerName.lowercased().contains(query) ||
            visit.postcode.lowercased().contains(query) ||
            visit.addressLine.lowercased().contains(query)
        }
    }

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                Section {
                    AppBrandHeader()
                        .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                }

                if viewModel.visits.isEmpty {
                    ContentUnavailableView(
                        "No Properties",
                        systemImage: "tray",
                        description: Text("Tap + to create a Property and start offline capture.")
                    )
                } else if filteredVisits.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ForEach(filteredVisits) { visit in
                        NavigationLink(value: visit.id) {
                            visitRow(for: visit)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.deleteVisit(id: filteredVisits[index].id)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search property, customer, postcode")
            .safeAreaInset(edge: .bottom) {
                AppBuildLabel()
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
            .navigationTitle("Properties")
            .navigationDestination(for: UUID.self) { visitID in
                PropertyTwinHomeView(
                    viewModel: viewModel,
                    visitID: visitID,
                    onRequestLeave: {
                        if viewModel.requestLeaveWorkingTwin(for: visitID) {
                            navigationPath.removeAll { $0 == visitID }
                        }
                    }
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Export Capture Package") {
                            if let url = viewModel.makeExportTempURL() {
                                shareURL = url
                                isPresentingShareSheet = true
                            }
                        }

                        Button("Import Capture Package") {
                            isPresentingImport = true
                        }
                    } label: {
                        Label("Property menu", systemImage: "ellipsis.circle")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingCreateVisit = true
                    } label: {
                        Label("Start Property Capture", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingCreateVisit) {
            CreateVisitView { reference, customerName, addressLine, postcode, engineerName, appointmentDate, notes, currentSystemType, captureMode in
                if let visitID = viewModel.createVisit(
                    reference: reference,
                    customerName: customerName,
                    addressLine: addressLine,
                    postcode: postcode,
                    engineerName: engineerName,
                    appointmentDate: appointmentDate,
                    notes: notes,
                    currentSystemType: currentSystemType,
                    captureMode: captureMode
                ) {
                    navigationPath = [visitID]
                }
            }
        }
        .sheet(isPresented: $isPresentingShareSheet) {
            if let url = shareURL {
                ActivityView(url: url)
            }
        }
        .fileImporter(
            isPresented: $isPresentingImport,
            allowedContentTypes: [.daedalusScanPackage, .json]
        ) { result in
            if case let .success(url) = result {
                viewModel.importPackage(from: url)
            } else if case let .failure(error) = result {
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .onOpenURL { url in
            viewModel.importPackage(from: url)
        }
        .confirmationDialog(
            viewModel.pendingWorkingTwinWarning?.kind.title ?? "Working Twin warning",
            isPresented: Binding(
                get: { viewModel.pendingWorkingTwinWarning != nil },
                set: { if !$0 { viewModel.cancelPendingWorkingTwinWarning() } }
            ),
            titleVisibility: .visible
        ) {
            if let warning = viewModel.pendingWorkingTwinWarning {
                Button(warning.kind.confirmTitle) {
                    let action = warning.action
                    let visitID = warning.visitID
                    viewModel.confirmPendingWorkingTwinWarning()
                    if action == .leave {
                        navigationPath.removeAll { $0 == visitID }
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelPendingWorkingTwinWarning()
            }
        } message: {
            Text(viewModel.pendingWorkingTwinWarning?.kind.message ?? "")
        }
        .confirmationDialog(
            "Import conflict",
            isPresented: Binding(
                get: { viewModel.pendingImportConflict != nil },
                set: { if !$0 { viewModel.cancelPendingImport() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Replace existing Property") {
                viewModel.replaceExistingVisitForPendingImport()
            }
            Button("Keep both") {
                viewModel.keepBothForPendingImport()
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelPendingImport()
            }
        } message: {
            if let conflict = viewModel.pendingImportConflict {
                if conflict.conflictCount == 1 {
                    Text("Imported Property \"\(conflict.sampleReference)\" already exists locally.")
                } else {
                    Text("\(conflict.conflictCount) imported Properties already exist locally.")
                }
            }
        }
        .alert(
            "Daedalus Capture",
            isPresented: Binding(
                get: { viewModel.statusMessage != nil },
                set: { if !$0 { viewModel.statusMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.statusMessage ?? "")
        }
        .alert(
            "Daedalus Capture",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func visitRow(for visit: Visit) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(visit.reference)
                    .font(.headline)
                Spacer()
                Text(visit.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !visit.customerName.isEmpty || !visit.postcode.isEmpty {
                let customerSummary = [visit.customerName, visit.postcode]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                Text(customerSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !visit.addressLine.isEmpty {
                Text(visit.addressLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 12) {
                Label("Version \(visit.twinVersion)", systemImage: "number")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Label("System · House · Home", systemImage: "building.2")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Label(visit.repositoryState.title, systemImage: "arrow.triangle.branch")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Label(visit.captureSessionStatus.title, systemImage: visit.captureSessionStatus.systemImage)
                    .font(.caption2)
                    .foregroundStyle(visit.hasUnreviewedEvidence ? .orange : .secondary)

                let reviewCount = reviewNeedsCount(for: visit)
                if reviewCount > 0 {
                    Label("\(reviewCount) needs review", systemImage: "eye")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func reviewNeedsCount(for visit: Visit) -> Int {
        let roomCount = visit.rooms.filter { $0.reviewStatus == .needsReview }.count
        let componentCount = visit.components.filter { $0.reviewStatus == .needsReview }.count
        let roomEvidenceCount = visit.rooms.reduce(0) { count, room in
            count + room.evidence.filter { $0.reviewStatus == .needsReview }.count
        }
        let componentEvidenceCount = visit.components.reduce(0) { count, component in
            count + component.evidence.filter { $0.reviewStatus == .needsReview }.count
        }
        return roomCount + componentCount + roomEvidenceCount + componentEvidenceCount
    }
}

private struct AppBrandHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.accentColor)
                Text("D")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 34, height: 34)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("Daedalus Capture")
                    .font(.headline)
                Text("Property-rooted offline scan")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AppBuildLabel: View {
    private var buildText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info?["CFBundleVersion"] as? String ?? "unknown"
        return "Daedalus Capture v\(version) (\(build))"
    }

    var body: some View {
        Text(buildText)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Daedalus Capture build \(buildText)")
    }
}
