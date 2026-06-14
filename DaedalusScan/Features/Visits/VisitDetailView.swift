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
                Section {
                    NavigationLink {
                        VisitSummaryView(visit: visit)
                    } label: {
                        Label("Capture Summary", systemImage: "checklist")
                    }

                    NavigationLink {
                        CaptureReviewWorkspaceView(viewModel: viewModel, visitID: visitID)
                    } label: {
                        Label("Capture Review", systemImage: "tray.full")
                    }

                    Button {
                        isPresentingContext = true
                    } label: {
                        Label("Property Twin Context", systemImage: "slider.horizontal.3")
                    }

                    Button {
                        if let url = viewModel.makeReviewedExportTempURL(for: visitID) {
                            shareURL = url
                            isPresentingShareSheet = true
                        }
                    } label: {
                        Label("Create Reviewed Capture Package", systemImage: "shippingbox")
                    }
                    .disabled(visit.hasBlockingCaptureReviewItems)
                } header: {
                    Text("Review")
                }

                Section {
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
                } header: {
                    Text("Captured Areas")
                } footer: {
                    Text("Manual area management is a secondary fallback/admin surface.")
                }

                Section {
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
                } header: {
                    Text("Captured Objects")
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
            Text("Property Twin not found")
                .foregroundStyle(.secondary)
        }
    }
}

struct VisitContextSheet: View {
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
                        "Lifecycle",
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
                        "Existing reality",
                        selection: Binding(
                            get: { visit.currentSystemType },
                            set: { viewModel.setCurrentSystemType($0, for: visitID) }
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
                ContentUnavailableView("Property Twin not found", systemImage: "exclamationmark.triangle")
            }
        }
    }
}
