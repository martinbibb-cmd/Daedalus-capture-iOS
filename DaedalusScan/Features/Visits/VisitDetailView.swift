import SwiftUI

struct VisitDetailView: View {
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID

    @State private var isPresentingShareSheet = false
    @State private var isPresentingContext = false

    @State private var shareURL: URL?

    var body: some View {
        if let visit = viewModel.visit(id: visitID) {
            List {
                Section("Review") {
                    NavigationLink {
                        VisitSummaryView(visit: visit)
                    } label: {
                        Label("Capture Summary", systemImage: "checklist")
                    }

                    Button {
                        isPresentingContext = true
                    } label: {
                        Label("Visit Context", systemImage: "slider.horizontal.3")
                    }

                    Button {
                        if let url = viewModel.makeExportTempURL(for: visitID) {
                            shareURL = url
                            isPresentingShareSheet = true
                        }
                    } label: {
                        Label("Export Package", systemImage: "square.and.arrow.up")
                    }
                }

                Section("Captured Areas") {
                    if visit.rooms.isEmpty {
                        Text("No areas captured yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(visit.rooms) { room in
                            NavigationLink(room.name) {
                                RoomDetailView(viewModel: viewModel, visitID: visitID, roomID: room.id)
                            }
                        }
                    }

                    Button("Add Area") {
                        viewModel.addRoom(to: visitID, named: "Scanned Area \(visit.rooms.count + 1)")
                    }
                } footer: {
                    Text("Manual area management is a secondary fallback/admin surface.")
                }

                Section("Captured Objects") {
                    let components = visit.components.filter { $0.captureMode == visit.captureMode }
                    if components.isEmpty {
                        Text("No objects captured yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(components) { component in
                            NavigationLink {
                                ComponentDetailView(
                                    viewModel: viewModel,
                                    visitID: visitID,
                                    componentID: component.id
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(component.kind.title)
                                    Text(component.spatialPlacement.confidence.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Review Capture")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isPresentingShareSheet) {
                if let url = shareURL {
                    ActivityView(url: url)
                }
            }
            .sheet(isPresented: $isPresentingContext) {
                VisitContextSheet(viewModel: viewModel, visitID: visitID)
            }
        } else {
            Text("Visit not found")
                .foregroundStyle(.secondary)
        }
    }
}

private struct VisitContextSheet: View {
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID

    private var visit: Visit? {
        viewModel.visit(id: visitID)
    }

    var body: some View {
        NavigationStack {
            if let visit {
                List {
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
                }
                .navigationTitle("Context")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView("Visit not found", systemImage: "exclamationmark.triangle")
            }
        }
    }
}
