import SwiftUI
import UIKit

struct VisitListView: View {
    @ObservedObject var viewModel: VisitListViewModel

    @State private var isPresentingCreateVisit = false
    @State private var isPresentingImport = false
    @State private var isPresentingShareSheet = false
    @State private var shareURL: URL?

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
            CreateVisitView { reference, twinKind in
                viewModel.createVisit(reference: reference, twinKind: twinKind)
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
}

private struct ActivityView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
