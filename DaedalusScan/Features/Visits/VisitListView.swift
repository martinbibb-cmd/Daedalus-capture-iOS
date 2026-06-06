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
        NavigationStack {
            List {
                if viewModel.visits.isEmpty {
                    ContentUnavailableView(
                        "No Visits",
                        systemImage: "tray",
                        description: Text("Create a visit to start capturing survey data and evidence.")
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
            .searchable(text: $searchText, prompt: "Search reference, customer, postcode")
            .navigationTitle("Visits")
            .navigationDestination(for: UUID.self) { visitID in
                VisitDetailView(viewModel: viewModel, visitID: visitID)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu("Package") {
                        Button("Export Visit Package") {
                            if let url = viewModel.makeExportTempURL() {
                                shareURL = url
                                isPresentingShareSheet = true
                            }
                        }

                        Button("Import Visit Package") {
                            isPresentingImport = true
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingCreateVisit = true
                    } label: {
                        Label("Create Visit", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingCreateVisit) {
            CreateVisitView { reference, customerName, addressLine, postcode, engineerName, appointmentDate, notes, currentSystemType, proposedSystemType, captureMode in
                viewModel.createVisit(
                    reference: reference,
                    customerName: customerName,
                    addressLine: addressLine,
                    postcode: postcode,
                    engineerName: engineerName,
                    appointmentDate: appointmentDate,
                    notes: notes,
                    currentSystemType: currentSystemType,
                    proposedSystemType: proposedSystemType,
                    captureMode: captureMode
                )
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
            "Import conflict",
            isPresented: Binding(
                get: { viewModel.pendingImportConflict != nil },
                set: { if !$0 { viewModel.cancelPendingImport() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Replace existing visit") {
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
                    Text("Imported visit \"\(conflict.sampleReference)\" already exists locally.")
                } else {
                    Text("\(conflict.conflictCount) imported visits already exist locally.")
                }
            }
        }
        .alert(
            "Daedalus Scan",
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
            "Daedalus Scan",
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
                Label("System · House · Home", systemImage: "building.2")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

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
        return roomCount + componentCount
    }
}
