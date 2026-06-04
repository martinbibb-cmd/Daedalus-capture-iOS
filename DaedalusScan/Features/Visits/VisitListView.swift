import SwiftUI

struct VisitListView: View {
    @ObservedObject var viewModel: VisitListViewModel

    @State private var isPresentingCreateVisit = false
    @State private var isPresentingImport = false
    @State private var isPresentingExport = false
    @State private var exportDocument = VisitExportDocument.empty

    var body: some View {
        NavigationStack {
            List {
                if viewModel.visits.isEmpty {
                    ContentUnavailableView(
                        "No Visits",
                        systemImage: "tray",
                        description: Text("Create a visit to start capturing survey data and evidence.")
                    )
                } else {
                    ForEach(viewModel.visits) { visit in
                        NavigationLink(value: visit.id) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(visit.reference)
                                    .font(.headline)
                                Text(visit.twinKind.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("\(visit.rooms.count) room\(visit.rooms.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.deleteVisit(id: viewModel.visits[index].id)
                        }
                    }
                }
            }
            .navigationTitle("Visits")
            .navigationDestination(for: UUID.self) { visitID in
                VisitDetailView(viewModel: viewModel, visitID: visitID)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu("Package") {
                        Button("Export Visits") {
                            if let document = viewModel.makeExportDocument() {
                                exportDocument = document
                                isPresentingExport = true
                            }
                        }

                        Button("Import Visits") {
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
            CreateVisitView { reference, twinKind in
                viewModel.createVisit(reference: reference, twinKind: twinKind)
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
        .fileExporter(
            isPresented: $isPresentingExport,
            document: exportDocument,
            contentType: .daedalusScanPackage,
            defaultFilename: "DaedalusScanExport"
        ) { result in
            if case let .failure(error) = result {
                viewModel.errorMessage = error.localizedDescription
            }
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
}
