import SwiftUI
import UIKit

struct LiveCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID

    @StateObject private var recordingService: ContinuousVisitRecordingService
    @State private var isPresentingReview = false
    @State private var isPresentingPhotoCapture = false

    @State private var capturedEvidenceComponentID: UUID?
    @State private var spatialSession = SpatialCaptureSession()
    @State private var livePlacementState = LivePlacementState.unavailable
    @State private var scanProgress = LiveSpatialScanProgress.empty
    @State private var confirmation: LiveCaptureConfirmation?
    @State private var isFocusModeActive = false
    @State private var didRequestSpatialStart = false

    private var visit: Visit? {
        viewModel.visit(id: visitID)
    }

    init(viewModel: VisitListViewModel, visitID: UUID) {
        self.viewModel = viewModel
        self.visitID = visitID
        _recordingService = StateObject(wrappedValue: ContinuousVisitRecordingService(viewModel: viewModel))
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
                                pauseForReview()
                            } label: {
                                Label("Pause & Review", systemImage: "list.bullet.rectangle")
                            }
                        }
                    }
                    .navigationDestination(isPresented: $isPresentingReview) {
                        CaptureReviewWorkspaceView(viewModel: viewModel, visitID: visitID, onResumeSurvey: resumeSurvey)
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
                requestSpatialSessionStart()
            }
    }

    private func liveCaptureSurface(visit: Visit) -> some View {
        ZStack {
            LiveSpatialCaptureView(
                progress: $scanProgress,
                isScanning: spatialSession.status == .scanning,
                isFocusModeActive: isFocusModeActive
            )
                .ignoresSafeArea()

            LiveSurveyCoverageOverlay(
                capturedSurfaceCount: scanProgress.capturedSurfaceCount,
                isFocusModeActive: isFocusModeActive
            )

            LinearGradient(
                colors: [.black.opacity(0.42), .clear, .black.opacity(0.66)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                LiveCaptureStatusBar(
                    reference: visit.reference,
                    sessionStatus: surveyStatusTitle,
                    sessionColor: sessionStatusColor,
                    placementLabel: surveyConfidenceLabel,
                    scanProgressLabel: surveyCoverageLabel,
                    onEnd: leaveSurvey
                )
                .padding(.horizontal, 16)
                .padding(.top, 14)

                Spacer()

                if let confirmation {
                    LiveCaptureConfirmationView(confirmation: confirmation)
                        .padding(.bottom, 18)
                }

                LiveCaptureMiniTimeline(visit: visit, scanProgress: scanProgress)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                LiveCaptureControlBar(
                    onSnapshot: { isPresentingPhotoCapture = true },
                    onVoiceNote: { createLiveEvidence(.voice) },
                    onFocus: toggleFocusMode,
                    onSafety: { createLiveEvidence(.safety) },
                    onReview: pauseForReview,
                    surveyCounts: LiveSurveyCounts(visit: visit),
                    isFocusModeActive: isFocusModeActive
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }

        }
        .onChange(of: scanProgress) { _, _ in
            syncPlacementStateForSession()
        }
    }

    private var currentPlacementMetadata: SpatialPlacement? {
        guard spatialSession.status == .scanning || spatialSession.status == .paused else {
            return nil
        }
        return livePlacementState.currentPlacement
    }

    private var surveyStatusTitle: String {
        if isFocusModeActive {
            return "Focusing"
        }
        return spatialSession.status == .scanning ? "Surveying" : spatialSession.status.title
    }

    private var surveyConfidenceLabel: String {
        if isFocusModeActive {
            return "Detail geometry capture active"
        }
        if livePlacementState.hasAnchor {
            return "Spatial confidence building"
        }
        if livePlacementState.lastKnownPosition != nil {
            return "Approximate coverage available"
        }
        return "Keep moving to build coverage"
    }

    private var surveyCoverageLabel: String {
        if scanProgress.hasGeometry {
            return isFocusModeActive ? "Focus: \(scanProgress.captureLabel)" : scanProgress.captureLabel
        }
        return recordingService.isRecording ? "Audio running" : "Starting survey record"
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
        recordingService.startRecording(visitID: visitID)
        syncPlacementStateForSession()
    }

    private func requestSpatialSessionStart() {
        guard !didRequestSpatialStart else { return }
        didRequestSpatialStart = true

        Task { @MainActor in
            await Task.yield()
            startSpatialSession()
        }
    }

    private func pauseSpatialSession() {
        guard spatialSession.status == .scanning else { return }
        spatialSession.status = .paused
    }

    private func completeSpatialSession() {
        guard spatialSession.status == .scanning || spatialSession.status == .paused else { return }
        spatialSession.status = .completed
        spatialSession.endedAt = Date()
        didRequestSpatialStart = false
        isFocusModeActive = false
        recordingService.stopRecording()
        livePlacementState = .unavailable
    }

    private func syncPlacementStateForSession() {
        guard spatialSession.status == .scanning else {
            livePlacementState = .unavailable
            return
        }
        if let placement = scanProgress.placement {
            livePlacementState = LivePlacementState(
                currentAnchor: placement.anchorID.map {
                    CapturedAnchor(
                        id: $0,
                        position: placement.approximatePosition,
                        confidence: placement.confidence
                    )
                },
                lastKnownPosition: placement.approximatePosition,
                lastUpdatedAt: scanProgress.lastUpdatedAt ?? Date()
            )
        } else {
            livePlacementState = LivePlacementState(
                currentAnchor: CapturedAnchor(
                    id: "session-\(spatialSession.id.uuidString)",
                    confidence: .low
                ),
                lastKnownPosition: nil,
                lastUpdatedAt: Date()
            )
        }
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
            positionLabel: scanProgress.hasGeometry ? scanProgress.captureLabel : surveyConfidenceLabel
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

    private func toggleFocusMode() {
        if isFocusModeActive {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                isFocusModeActive = false
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                isFocusModeActive = true
            }
            createLiveEvidence(.mark)
        }
    }

    private func pauseForReview() {
        completeSpatialSession()
        viewModel.refreshCaptureReviewSuggestions(for: visitID)
        isPresentingReview = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func leaveSurvey() {
        completeSpatialSession()
        dismiss()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func resumeSurvey() {
        isPresentingReview = false
        requestSpatialSessionStart()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

private struct LiveCaptureConfirmation: Equatable {
    var kind: LiveCaptureEvidenceKind
    var anchored: Bool
}

private struct LiveCaptureStatusBar: View {
    let reference: String
    let sessionStatus: String
    let sessionColor: Color
    let placementLabel: String
    let scanProgressLabel: String
    let onEnd: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 9, height: 9)
                    Text("Survey in progress")
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
                Label(scanProgressLabel, systemImage: "cube.transparent")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Button(action: onEnd) {
                    Text("End")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.red.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.red.opacity(0.72), lineWidth: 1)
                        )
                        .foregroundStyle(.red)
                }
                .accessibilityLabel("End survey")
            }
        }
        .padding(12)
        .background(.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct LiveSurveyCoverageOverlay: View {
    let capturedSurfaceCount: Int
    let isFocusModeActive: Bool

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                if isFocusModeActive {
                    focusReticle(in: proxy.size)
                }

                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(0..<6, id: \.self) { index in
                            Capsule()
                                .fill(index < min(capturedSurfaceCount, 6) ? Color.green.opacity(0.84) : Color.white.opacity(0.28))
                                .frame(width: 30, height: 5)
                        }
                    }
                    .padding(.bottom, 150)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func focusReticle(in size: CGSize) -> some View {
        let width = size.width
        let height = size.height
        let rect = CGRect(x: width * 0.18, y: height * 0.25, width: width * 0.64, height: height * 0.44)

        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.yellow.opacity(0.94), style: StrokeStyle(lineWidth: 2.2, dash: [9, 5]))
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)

            Path { path in
                for corner in focusCorners(in: rect) {
                    path.move(to: corner.horizontalStart)
                    path.addLine(to: corner.point)
                    path.addLine(to: corner.verticalEnd)
                    path.move(to: corner.verticalStart)
                    path.addLine(to: corner.point)
                    path.addLine(to: corner.horizontalEnd)
                }
            }
            .stroke(Color.yellow, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

            Circle()
                .stroke(Color.yellow.opacity(0.82), lineWidth: 2)
                .frame(width: 78, height: 78)
                .position(x: rect.midX, y: rect.midY)
            Circle()
                .fill(Color.yellow.opacity(0.92))
                .frame(width: 10, height: 10)
                .position(x: rect.midX, y: rect.midY)
        }
    }

    private func focusCorners(in rect: CGRect) -> [FocusCorner] {
        let tick: CGFloat = 32
        return [
            FocusCorner(
                point: CGPoint(x: rect.minX, y: rect.minY),
                horizontalStart: CGPoint(x: rect.minX + tick, y: rect.minY),
                horizontalEnd: CGPoint(x: rect.minX + tick, y: rect.minY),
                verticalStart: CGPoint(x: rect.minX, y: rect.minY + tick),
                verticalEnd: CGPoint(x: rect.minX, y: rect.minY + tick)
            ),
            FocusCorner(
                point: CGPoint(x: rect.maxX, y: rect.minY),
                horizontalStart: CGPoint(x: rect.maxX - tick, y: rect.minY),
                horizontalEnd: CGPoint(x: rect.maxX - tick, y: rect.minY),
                verticalStart: CGPoint(x: rect.maxX, y: rect.minY + tick),
                verticalEnd: CGPoint(x: rect.maxX, y: rect.minY + tick)
            ),
            FocusCorner(
                point: CGPoint(x: rect.maxX, y: rect.maxY),
                horizontalStart: CGPoint(x: rect.maxX - tick, y: rect.maxY),
                horizontalEnd: CGPoint(x: rect.maxX - tick, y: rect.maxY),
                verticalStart: CGPoint(x: rect.maxX, y: rect.maxY - tick),
                verticalEnd: CGPoint(x: rect.maxX, y: rect.maxY - tick)
            ),
            FocusCorner(
                point: CGPoint(x: rect.minX, y: rect.maxY),
                horizontalStart: CGPoint(x: rect.minX + tick, y: rect.maxY),
                horizontalEnd: CGPoint(x: rect.minX + tick, y: rect.maxY),
                verticalStart: CGPoint(x: rect.minX, y: rect.maxY - tick),
                verticalEnd: CGPoint(x: rect.minX, y: rect.maxY - tick)
            )
        ]
    }
}

private struct FocusCorner {
    let point: CGPoint
    let horizontalStart: CGPoint
    let horizontalEnd: CGPoint
    let verticalStart: CGPoint
    let verticalEnd: CGPoint
}

private struct LiveCaptureControlBar: View {
    let onSnapshot: () -> Void
    let onVoiceNote: () -> Void
    let onFocus: () -> Void
    let onSafety: () -> Void
    let onReview: () -> Void
    let surveyCounts: LiveSurveyCounts
    let isFocusModeActive: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                liveButton("Snapshot", systemImage: "camera.fill", action: onSnapshot)
                liveButton("Note", systemImage: "waveform", action: onVoiceNote)
                liveButton(
                    isFocusModeActive ? "Stop" : "Focus",
                    systemImage: isFocusModeActive ? "xmark.circle.fill" : "scope",
                    tint: isFocusModeActive ? .yellow : .white,
                    action: onFocus
                )
                liveButton("Safety", systemImage: "exclamationmark.triangle.fill", tint: .red, action: onSafety)
                liveButton("Review", systemImage: "list.bullet.rectangle", action: onReview)
            }

            HStack(spacing: 18) {
                surveyCount("Rooms", value: surveyCounts.rooms)
                surveyCount("Areas", value: surveyCounts.areas)
                surveyCount("Items", value: surveyCounts.items)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
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

    private func surveyCount(_ title: String, value: Int) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Text("\(value)")
                .fontWeight(.semibold)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.white.opacity(0.9))
    }
}

private struct LiveSurveyCounts {
    let rooms: Int
    let areas: Int
    let items: Int

    init(visit: Visit) {
        rooms = visit.areas.count
        areas = visit.areas.count
        items = visit.components.count
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
    let scanProgress: LiveSpatialScanProgress

    private var entries: [EvidenceTimelineEntry] {
        Array(visit.evidenceTimelineEntries.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if entries.isEmpty {
                Text(scanProgress.hasGeometry ? "Detected geometry · \(scanProgress.captureLabel)" : "Move slowly to detect walls, openings, and corners")
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
