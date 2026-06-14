import SwiftUI
import UIKit

struct LiveCaptureView: View {
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID

    @State private var isPresentingReview = false
    @State private var isPresentingPhotoCapture = false
    @State private var isPresentingShareSheet = false
    @State private var shareURL: URL?

    @State private var capturedEvidenceComponentID: UUID?
    @State private var spatialSession = SpatialCaptureSession()
    @State private var livePlacementState = LivePlacementState.unavailable
    @State private var confirmation: LiveCaptureConfirmation?
    @State private var finishStatus: LiveCaptureFinishStatus?

    private var visit: Visit? {
        viewModel.visit(id: visitID)
    }

    var body: some View {
        Group {
            if let visit {
                cameraFirstCapture(visit: visit)
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.hidden, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                isPresentingReview = true
                            } label: {
                                Label("Review", systemImage: "list.bullet.rectangle")
                            }
                        }
                    }
                    .navigationDestination(isPresented: $isPresentingReview) {
                        VisitDetailView(viewModel: viewModel, visitID: visitID)
                    }
                    .sheet(isPresented: $isPresentingShareSheet) {
                        if let url = shareURL {
                            ActivityView(url: url)
                        }
                    }
                    .sheet(isPresented: $isPresentingPhotoCapture) {
                        CameraCaptureView { data in
                            createLiveEvidence(.photo, photoData: data)
                        }
                    }
            } else {
                ContentUnavailableView("Property Twin not found", systemImage: "exclamationmark.triangle")
            }
        }
    }

    @ViewBuilder
    private func cameraFirstCapture(visit: Visit) -> some View {
        liveCaptureSurface(visit: visit)
            .ignoresSafeArea()
            .onAppear {
                startSpatialSession()
            }
    }

    private func liveCaptureSurface(visit: Visit) -> some View {
        ZStack {
            LiveCameraPreviewView()
                .ignoresSafeArea()

            GeometryOverlay(isAnchored: livePlacementState.hasAnchor)

            LinearGradient(
                colors: [.black.opacity(0.42), .clear, .black.opacity(0.66)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                LiveCaptureStatusBar(
                    reference: visit.reference,
                    sessionStatus: spatialSession.status.title,
                    sessionColor: sessionStatusColor,
                    placementLabel: placementLabel
                )
                .padding(.horizontal, 16)
                .padding(.top, 14)

                Spacer()

                if let confirmation {
                    LiveCaptureConfirmationView(confirmation: confirmation)
                        .padding(.bottom, 18)
                }

                LiveCaptureMiniTimeline(visit: visit)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                LiveCaptureControlBar(
                    onPhoto: { isPresentingPhotoCapture = true },
                    onMark: { createLiveEvidence(.mark) },
                    onSafety: { createLiveEvidence(.safety) },
                    onFinish: finishVisit
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }

            if let finishStatus {
                LiveCaptureFinishPanel(
                    status: finishStatus,
                    onShare: {
                        shareURL = finishStatus.exportURL
                        isPresentingShareSheet = true
                    },
                    onReview: { isPresentingReview = true }
                )
                .padding(.horizontal, 20)
            }
        }
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
        return "No anchor - fallback active"
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

    private func createLiveEvidence(_ kind: LiveCaptureEvidenceKind, photoData: Data? = nil) {
        let componentID = viewModel.addLiveCaptureEvidence(
            to: visitID,
            kind: kind,
            placement: currentPlacementMetadata,
            photoData: photoData,
            scanSessionID: spatialSession.id,
            cameraFrameReference: photoData == nil ? nil : "current-frame",
            geometryAnchorID: currentPlacementMetadata?.anchorID,
            positionLabel: placementLabel
        )
        capturedEvidenceComponentID = componentID

        let hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = kind == .safety ? .heavy : .medium
        UIImpactFeedbackGenerator(style: hapticStyle).impactOccurred()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            confirmation = LiveCaptureConfirmation(kind: kind, anchored: currentPlacementMetadata != nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.18)) {
                confirmation = nil
            }
        }
    }

    private func finishVisit() {
        completeSpatialSession()
        guard let url = viewModel.makeExportTempURL(for: visitID) else {
            withAnimation {
                finishStatus = LiveCaptureFinishStatus(message: "Export package could not be created.", exportURL: nil)
            }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }

        withAnimation {
            finishStatus = LiveCaptureFinishStatus(message: "Export package ready.", exportURL: url)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

private struct LiveCaptureConfirmation: Equatable {
    var kind: LiveCaptureEvidenceKind
    var anchored: Bool
}

private struct LiveCaptureFinishStatus: Equatable {
    var message: String
    var exportURL: URL?
}

private struct LiveCaptureStatusBar: View {
    let reference: String
    let sessionStatus: String
    let sessionColor: Color
    let placementLabel: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 9, height: 9)
                    Text("Recording")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)

                Text(reference)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 7) {
                Label(sessionStatus, systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(sessionColor)
                Label(placementLabel, systemImage: "location")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(12)
        .background(.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct GeometryOverlay: View {
    let isAnchored: Bool

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height
                Path { path in
                    let midY = height * 0.47
                    path.move(to: CGPoint(x: width * 0.18, y: midY))
                    path.addLine(to: CGPoint(x: width * 0.82, y: midY))
                    path.move(to: CGPoint(x: width * 0.5, y: height * 0.2))
                    path.addLine(to: CGPoint(x: width * 0.5, y: height * 0.76))
                    path.addRoundedRect(in: CGRect(x: width * 0.22, y: height * 0.28, width: width * 0.56, height: height * 0.36), cornerSize: CGSize(width: 14, height: 14))
                }
                .stroke(isAnchored ? Color.green.opacity(0.72) : Color.white.opacity(0.42), style: StrokeStyle(lineWidth: 1.4, dash: [7, 7]))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct LiveCaptureControlBar: View {
    let onPhoto: () -> Void
    let onMark: () -> Void
    let onSafety: () -> Void
    let onFinish: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            liveButton("Photo", systemImage: "camera.fill", action: onPhoto)
            liveButton("Mark", systemImage: "mappin.and.ellipse", action: onMark)
            liveButton("Safety", systemImage: "exclamationmark.triangle.fill", tint: .red, action: onSafety)
            liveButton("Finish", systemImage: "checkmark.circle.fill", action: onFinish)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func liveButton(
        _ title: String,
        systemImage: String,
        tint: Color = .white,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                Text(title)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct LiveCaptureConfirmationView: View {
    let confirmation: LiveCaptureConfirmation

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: confirmation.kind == .safety ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            Text("\(confirmation.kind.title) saved")
            Text(confirmation.anchored ? "anchored" : "geometry pending")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(confirmation.kind == .safety ? Color.red.opacity(0.92) : Color.black.opacity(0.72), in: Capsule())
        .foregroundStyle(.white)
    }
}

private struct LiveCaptureMiniTimeline: View {
    let visit: Visit

    private var entries: [EvidenceTimelineEntry] {
        Array(visit.evidenceTimelineEntries.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if entries.isEmpty {
                Text("Geometry not available yet")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.84))
            } else {
                ForEach(entries) { entry in
                    HStack(spacing: 8) {
                        Text(entry.capturedAt.formatted(date: .omitted, time: .shortened))
                            .monospacedDigit()
                        Text(entry.evidenceType)
                        Spacer()
                        Text(anchorText(for: entry))
                            .foregroundStyle(.white.opacity(0.76))
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                }
            }
        }
        .padding(10)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func anchorText(for entry: EvidenceTimelineEntry) -> String {
        guard let spatialContext = entry.spatialContext, !spatialContext.isEmpty else {
            return "geometry pending"
        }
        if spatialContext.localizedCaseInsensitiveContains("geometry") ||
            spatialContext.localizedCaseInsensitiveContains("anchor") {
            return "anchored"
        }
        return "audio + geometry"
    }
}

private struct LiveCaptureFinishPanel: View {
    let status: LiveCaptureFinishStatus
    let onShare: () -> Void
    let onReview: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Label(status.message, systemImage: status.exportURL == nil ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                .font(.headline.weight(.semibold))
            HStack(spacing: 10) {
                Button(action: onReview) {
                    Label("Review", systemImage: "list.bullet.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: onShare) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(status.exportURL == nil)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

private struct ARQuickEvidenceRequest {
    var subtype: SystemComponentSubtype
    var areaID: UUID?
    var photoData: Data?
    var voiceNoteText: String
    var includeGeometry: Bool
    var floorLevel: String
    var geometryID: String
    var approximatePositionLabel: String
}

private struct ARQuickEvidenceSheet: View {
    @Environment(\.dismiss) private var dismiss

    let areas: [Room]
    let onCapture: (ARQuickEvidenceRequest) -> Void

    @State private var subtype: SystemComponentSubtype = .unknownHeatSource
    @State private var selectedAreaID: UUID?
    @State private var photoData: Data?
    @State private var isPresentingCamera = false
    @State private var voiceNoteText = ""
    @State private var includeGeometry = true
    @State private var floorLevel = "Ground floor"
    @State private var geometryID = ""
    @State private var approximatePositionLabel = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Component", selection: $subtype) {
                        ForEach(SystemComponentCategory.allCases.filter { $0 != .unknown }, id: \.id) { category in
                            Section(category.title) {
                                ForEach(SystemComponentSubtype.allCases.filter { $0.category == category }) { option in
                                    Text(option.title).tag(option)
                                }
                            }
                        }
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("What was observed")
                }

                Section {
                    EvidenceCardView(
                        title: "Component Type",
                        systemImage: "cube",
                        detail: subtype.title,
                        reviewStatus: .needsReview,
                        capturedAt: nil
                    )

                    EvidenceCardView(
                        title: "Area / Location",
                        systemImage: "location",
                        detail: areaDetail,
                        reviewStatus: .needsReview,
                        capturedAt: nil,
                        spatialContext: spatialContextDetail
                    )

                    Button {
                        isPresentingCamera = true
                    } label: {
                        EvidenceCardView(
                            title: "Picture",
                            systemImage: "photo",
                            detail: photoData == nil ? "Tap to capture picture evidence." : "Picture captured.",
                            reviewStatus: photoData == nil ? nil : .needsReview,
                            capturedAt: photoData == nil ? nil : Date()
                        )
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 8) {
                        EvidenceCardView(
                            title: "Voice Note",
                            systemImage: "waveform",
                            detail: voiceNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "Speak naturally when transcription is available. Type fallback here for now."
                                : voiceNoteText,
                            reviewStatus: voiceNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : .needsReview,
                            capturedAt: voiceNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : Date()
                        )
                        TextField("Voice Note fallback", text: $voiceNoteText, axis: .vertical)
                            .lineLimit(2...4)
                    }

                    Toggle(isOn: $includeGeometry) {
                        EvidenceCardView(
                            title: "Geometry",
                            systemImage: "scope",
                            detail: includeGeometry ? geometryDetail : "No geometry selected.",
                            reviewStatus: includeGeometry ? .needsReview : nil,
                            capturedAt: includeGeometry ? Date() : nil,
                            spatialContext: spatialContextDetail
                        )
                    }
                } header: {
                    Text("Evidence")
                } footer: {
                    Text("Capture evidence first. Typed Voice Note is a fallback until live transcription is available.")
                }

                Section {
                    TextField("Floor / level", text: $floorLevel)
                        .textInputAutocapitalization(.words)

                    if areas.isEmpty {
                        Text("No areas captured yet. Evidence will remain spatial until an area is added.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Area", selection: $selectedAreaID) {
                            Text("None").tag(Optional<UUID>.none)
                            ForEach(areas) { area in
                                Text(area.name).tag(Optional(area.id))
                            }
                        }
                    }

                    TextField("Geometry ID (optional)", text: $geometryID)
                        .textInputAutocapitalization(.characters)
                    TextField("Approximate position (optional)", text: $approximatePositionLabel)
                        .textInputAutocapitalization(.sentences)
                } header: {
                    Text("Spatial Context")
                }
            }
            .navigationTitle("Quick Evidence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Capture") {
                        onCapture(
                            ARQuickEvidenceRequest(
                                subtype: subtype,
                                areaID: selectedAreaID,
                                photoData: photoData,
                                voiceNoteText: voiceNoteText,
                                includeGeometry: includeGeometry,
                                floorLevel: floorLevel,
                                geometryID: geometryID,
                                approximatePositionLabel: approximatePositionLabel
                            )
                        )
                        dismiss()
                    }
                    .disabled(photoData == nil && voiceNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !includeGeometry)
                }
            }
            .sheet(isPresented: $isPresentingCamera) {
                CameraCaptureView { data in
                    photoData = data
                }
            }
        }
    }

    private var areaDetail: String {
        guard let selectedAreaID,
              let area = areas.first(where: { $0.id == selectedAreaID }) else {
            return "Spatial capture"
        }
        return area.name
    }

    private var geometryDetail: String {
        let trimmedGeometry = geometryID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGeometry.isEmpty else {
            return "Selected geometry captured."
        }
        return "Geometry \(trimmedGeometry)"
    }

    private var spatialContextDetail: String {
        [
            floorLevel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown level" : floorLevel,
            areaDetail,
            approximatePositionLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: " / ")
    }
}
