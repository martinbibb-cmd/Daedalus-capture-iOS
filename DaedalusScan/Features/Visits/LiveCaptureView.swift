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
    @State private var isPresentingWaterTest = false
    @State private var isPresentingServicePoint = false
    @State private var spatialSession = SpatialCaptureSession()
    @State private var livePlacementState = LivePlacementState.unavailable

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
                            viewModel.addRoom(to: visitID, named: name, placement: currentPlacementMetadata)
                        }
                    }
                    .sheet(isPresented: $isPresentingCaptureObject) {
                        CaptureObjectSheet(areas: visit.areas) { subtype, areaID in
                            _ = viewModel.addSpatialObject(
                                to: visitID,
                                kind: subtype.legacyKind,
                                subtype: subtype,
                                areaID: areaID,
                                placement: currentPlacementMetadata
                            )
                        }
                    }
                    .sheet(isPresented: $isPresentingAttachEvidence) {
                        AttachEvidenceSheet(viewModel: viewModel, visitID: visitID)
                    }
                    .sheet(isPresented: $isPresentingWaterTest) {
                        WaterSupplyTestSheet(viewModel: viewModel, visitID: visitID)
                    }
                    .sheet(isPresented: $isPresentingServicePoint) {
                        ServicePointSheet(viewModel: viewModel, visitID: visitID, visit: visit)
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
                    .onAppear {
                        syncPlacementStateForSession()
                    }

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

                        if visit.areas.isEmpty {
                            Text("No areas captured yet.")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.bottom, 12)
                        } else {
                            ForEach(visit.areas) { room in
                                NavigationLink {
                                    RoomDetailView(viewModel: viewModel, visitID: visitID, roomID: room.id)
                                } label: {
                                    SpatialAreaRow(room: room)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                                if room.id != visit.areas.last?.id {
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
                        Text("Captured Components")
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
                                    SpatialObjectRow(component: component)
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

                        Text("Unknown subtypes remain valid capture.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 12)
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    CaptureLedgerCard(visit: visit)
                    WaterSupplyLedgerCard(observations: visit.waterSupplyObservations)
                    ServicePointLedgerCard(observations: visit.servicePointObservations)
                    CompletenessOverlayCard(visit: visit)
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

                VStack(alignment: .leading, spacing: 8) {
                    Text("Live capture")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Label("Spatial session: \(spatialSession.status.title)", systemImage: "dot.radiowaves.left.and.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(sessionStatusColor)
                    Label(placementLabel, systemImage: "location")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            spatialSessionControls
                .background(Color(.tertiarySystemGroupedBackground))

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
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
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
                isPresentingWaterTest = true
            } label: {
                Label("Water Test", systemImage: "drop")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                isPresentingServicePoint = true
            } label: {
                Label("Service Point", systemImage: "faucet")
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

    private var spatialSessionControls: some View {
        HStack(spacing: 10) {
            Button {
                startSpatialSession()
            } label: {
                Label("Start", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(spatialSession.status == .scanning)

            Button {
                pauseSpatialSession()
            } label: {
                Label("Pause", systemImage: "pause.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(spatialSession.status != .scanning)

            Button {
                completeSpatialSession()
            } label: {
                Label("Complete", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(spatialSession.status != .scanning && spatialSession.status != .paused)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var currentPlacementMetadata: SpatialPlacement? {
        guard spatialSession.status == .scanning || spatialSession.status == .paused else {
            return nil
        }
        return livePlacementState.currentPlacement
    }

    private var placementLabel: String {
        if livePlacementState.hasAnchor {
            return "Placement anchor available"
        }
        return "No anchor — fallback active"
    }

    private var sessionStatusColor: Color {
        switch spatialSession.status {
        case .scanning:
            return .green
        case .paused:
            return .yellow
        case .failed:
            return .red
        case .completed:
            return .blue
        case .notStarted:
            return .white
        }
    }

    private func startSpatialSession() {
        if spatialSession.status == .completed || spatialSession.status == .failed {
            spatialSession.id = UUID()
        }
        if spatialSession.startedAt == nil || spatialSession.status == .completed || spatialSession.status == .failed {
            spatialSession.startedAt = Date()
        }
        spatialSession.endedAt = nil
        spatialSession.status = .scanning
        syncPlacementStateForSession()
    }

    private func pauseSpatialSession() {
        guard spatialSession.status == .scanning else { return }
        spatialSession.status = .paused
    }

    private func completeSpatialSession() {
        guard spatialSession.status == .scanning || spatialSession.status == .paused else { return }
        spatialSession.status = .completed
        spatialSession.endedAt = Date()
        livePlacementState = .unavailable
    }

    private func syncPlacementStateForSession() {
        guard spatialSession.status == .scanning else {
            livePlacementState = .unavailable
            return
        }
        livePlacementState = LivePlacementState(
            currentAnchor: CapturedAnchor(
                id: "session-\(spatialSession.id.uuidString)",
                confidence: .medium
            ),
            lastKnownPosition: nil,
            lastUpdatedAt: Date()
        )
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

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(component.canonicalSubtype.title)
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

private struct CaptureLedgerCard: View {
    let visit: Visit

    private var components: [SystemComponent] {
        visit.components.filter { $0.captureMode == visit.captureMode }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Capture Ledger")
                .font(.subheadline.weight(.semibold))
            ForEach(SystemComponentCategory.allCases.filter { $0 != .unknown }, id: \.id) { category in
                let count = components.filter { $0.canonicalCategory == category }.count
                HStack {
                    Text(category.title)
                    Spacer()
                    Text(count == 0 ? "?" : count == 1 ? "✓" : "\(count) captured")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
            HStack {
                Text("Evidence")
                Spacer()
                Text("\(visit.rooms.reduce(0) { $0 + $1.evidence.count } + components.reduce(0) { $0 + $1.evidence.count }) items")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct WaterSupplyLedgerCard: View {
    let observations: [WaterSupplyObservation]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Water Supply")
                .font(.subheadline.weight(.semibold))
            if observations.isEmpty {
                Text("No water tests captured.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(observations.prefix(3)) { observation in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(observation.method.title)
                            Text("\(observation.location.rawValue) · \(observation.confidence.rawValue)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(observation.values.isEmpty ? "not tested" : "\(observation.values.count) values")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ServicePointLedgerCard: View {
    let observations: [ServicePointObservation]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Service Points")
                .font(.subheadline.weight(.semibold))
            if observations.isEmpty {
                Text("No outlets captured.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(observations.prefix(3)) { observation in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(observation.servicePointType.rawValue)
                            Text("\(observation.supplyType.rawValue) · \(observation.intendedPressureType.rawValue)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(observation.observedIssues.isEmpty ? "no issues" : "\(observation.observedIssues.count) issues")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct CompletenessOverlayCard: View {
    let visit: Visit

    private var components: [SystemComponent] {
        visit.components.filter { $0.captureMode == visit.captureMode }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Observed")
                .font(.subheadline.weight(.semibold))
            overlayRow("Heat Source", observed: components.contains { $0.canonicalCategory == .heatSource })
            overlayRow("Hot Water", observed: components.contains { $0.canonicalCategory == .hotWater })
            overlayRow("Controls", observed: components.contains { $0.canonicalCategory == .control })
            overlayRow("Emitters", observed: components.contains { $0.canonicalCategory == .emitter })
            overlayRow("Meters", observed: components.contains { $0.canonicalSubtype == .gasMeter })
            overlayRow("Water Supply", observed: !visit.waterSupplyObservations.isEmpty)
            overlayRow("Service Points", observed: !visit.servicePointObservations.isEmpty)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func overlayRow(_ label: String, observed: Bool) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(observed ? "✓" : "?")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}
