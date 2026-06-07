import SwiftUI

struct LiveCaptureView: View {
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID

    @State private var isPresentingReview = false
    @State private var isPresentingSummary = false
    @State private var isPresentingShareSheet = false
    @State private var isPresentingContext = false
    @State private var isPresentingCameraMode = false
    @State private var shareURL: URL?

    @State private var isPresentingCaptureArea = false
    @State private var isPresentingCaptureObject = false
    @State private var isPresentingAttachEvidence = false

    private var visit: Visit? {
        viewModel.visit(id: visitID)
    }

    var body: some View {
        Group {
            if let visit {
                entityList(visit: visit)
                    .navigationTitle(visit.reference)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                isPresentingReview = true
                            } label: {
                                Label("Review Capture", systemImage: "list.bullet.rectangle")
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Button("Visit Context") { isPresentingContext = true }
                                Button("Capture Summary") { isPresentingSummary = true }
                                Button("Camera Mode") { isPresentingCameraMode = true }
                                Divider()
                                Button("Export Package") {
                                    if let url = viewModel.makeExportTempURL(for: visitID) {
                                        shareURL = url
                                        isPresentingShareSheet = true
                                    }
                                }
                            } label: {
                                Label("Capture Tools", systemImage: "ellipsis.circle")
                            }
                        }
                    }
                    .navigationDestination(isPresented: $isPresentingReview) {
                        VisitDetailView(viewModel: viewModel, visitID: visitID)
                    }
                    .navigationDestination(isPresented: $isPresentingSummary) {
                        VisitSummaryView(visit: visit)
                    }
                    .navigationDestination(isPresented: $isPresentingCameraMode) {
                        SurveySectionCaptureView(viewModel: viewModel, visitID: visitID)
                    }
                    .sheet(isPresented: $isPresentingShareSheet) {
                        if let url = shareURL {
                            ActivityView(url: url)
                        }
                    }
                    .sheet(isPresented: $isPresentingContext) {
                        VisitContextSheet(viewModel: viewModel, visitID: visitID)
                    }
                    .sheet(isPresented: $isPresentingCaptureArea) {
                        CaptureAreaSheet { name in
                            viewModel.addRoom(to: visitID, named: name)
                        }
                    }
                    .sheet(isPresented: $isPresentingCaptureObject) {
                        CaptureObjectSheet(areas: visit.rooms) { kind, areaID in
                            _ = viewModel.addSpatialObject(to: visitID, kind: kind, areaID: areaID)
                        }
                    }
                    .sheet(isPresented: $isPresentingAttachEvidence) {
                        AttachEvidenceSheet(viewModel: viewModel, visitID: visitID)
                    }
            } else {
                ContentUnavailableView("Visit not found", systemImage: "exclamationmark.triangle")
            }
        }
    }

    @ViewBuilder
    private func entityList(visit: Visit) -> some View {
        List {
            Section("Captured Areas") {
                if visit.rooms.isEmpty {
                    Text("No areas captured yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(visit.rooms) { room in
                        NavigationLink {
                            RoomDetailView(viewModel: viewModel, visitID: visitID, roomID: room.id)
                        } label: {
                            SpatialAreaRow(room: room)
                        }
                    }
                }
            } footer: {
                Text("captureState: approximate  •  confidence: approximate")
                    .font(.caption2)
            }

            let components = visit.components.filter { $0.captureMode == visit.captureMode }
            Section("Captured Objects") {
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
                            SpatialObjectRow(component: component, rooms: visit.rooms)
                        }
                    }
                }
            } footer: {
                Text("Objects with area: roomAttached  •  Without area: evidenceOnly")
                    .font(.caption2)
            }
        }
        .safeAreaInset(edge: .bottom) {
            primaryActions
        }
    }

    private var primaryActions: some View {
        HStack(spacing: 10) {
            Button {
                isPresentingCaptureArea = true
            } label: {
                Label("Capture Area", systemImage: "square.dashed")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                isPresentingCaptureObject = true
            } label: {
                Label("Capture Object", systemImage: "cube")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                isPresentingAttachEvidence = true
            } label: {
                Label("Evidence", systemImage: "paperclip")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

private struct SpatialAreaRow: View {
    let room: Room

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(room.name)
            HStack(spacing: 8) {
                Label(room.spatialPlacement.captureState.title, systemImage: "location")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !room.evidence.isEmpty {
                    Label("\(room.evidence.count)", systemImage: "paperclip")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct SpatialObjectRow: View {
    let component: SystemComponent
    let rooms: [Room]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(component.kind.title)
            HStack(spacing: 8) {
                Label(placementLabel, systemImage: "location")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !component.evidence.isEmpty {
                    Label("\(component.evidence.count)", systemImage: "paperclip")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var placementLabel: String {
        if let location = component.componentAttributes["location"], !location.isEmpty {
            return location
        }
        return component.spatialPlacement.captureState.title
    }
}
