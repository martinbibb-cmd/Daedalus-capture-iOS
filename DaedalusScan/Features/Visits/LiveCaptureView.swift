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
                cameraFirstCapture(visit: visit)
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
                            Button {
                                isPresentingCameraMode = true
                            } label: {
                                Label("Camera Mode", systemImage: "camera.viewfinder")
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Button("Visit Context") { isPresentingContext = true }
                                Button("Capture Summary") { isPresentingSummary = true }
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
    private func cameraFirstCapture(visit: Visit) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                liveCaptureSurface

                VStack(alignment: .leading, spacing: 14) {
                    Text("Captured so far")
                        .font(.headline)
                        .padding(.horizontal, 14)
                        .padding(.top, 14)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Captured Areas")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.top, 12)
                            .padding(.bottom, 8)

                        if visit.rooms.isEmpty {
                            Text("No areas captured yet.")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.bottom, 12)
                        } else {
                            ForEach(visit.rooms) { room in
                                NavigationLink {
                                    RoomDetailView(viewModel: viewModel, visitID: visitID, roomID: room.id)
                                } label: {
                                    SpatialAreaRow(room: room)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                                if room.id != visit.rooms.last?.id {
                                    Divider()
                                        .padding(.leading, 14)
                                }
                            }
                            .padding(.bottom, 8)
                        }

                        Text("captureState: approximate  •  confidence: approximate")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 12)
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    let components = visit.components.filter { $0.captureMode == visit.captureMode }
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Captured Objects")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.top, 12)
                            .padding(.bottom, 8)

                        if components.isEmpty {
                            Text("No objects captured yet.")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.bottom, 12)
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
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                                if component.id != components.last?.id {
                                    Divider()
                                        .padding(.leading, 14)
                                }
                            }
                            .padding(.bottom, 8)
                        }

                        Text("Objects with area: roomAttached  •  Without area: evidenceOnly")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 12)
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var liveCaptureSurface: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                LiveCameraPreviewView()
                    .frame(height: 280)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Text("Live capture")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            primaryActions
                .background(Color(.secondarySystemGroupedBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
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
