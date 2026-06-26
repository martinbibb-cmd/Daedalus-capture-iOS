import SwiftUI
import UIKit

struct LiveCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID

    @StateObject private var recordingService: ContinuousVisitRecordingService
    @State private var isPresentingReview = false

    @State private var capturedEvidenceComponentID: UUID?
    @State private var spatialSession = SpatialCaptureSession()
    @State private var livePlacementState = LivePlacementState.unavailable
    @State private var scanProgress = LiveSpatialScanProgress.empty
    @State private var spatialAim = LiveSpatialAim.empty
    @State private var captureState: LiveCaptureState = .idle
    @State private var snapshotRequestID: UUID?
    @State private var didRequestSpatialStart = false
    @State private var activeSideDrawer: LiveCaptureSideDrawer?
    @State private var activeCaptureSheet: LiveCaptureSheet?
    @State private var isPresentingFocusWarning = false
    @State private var rulerStartPosition: SpatialPosition?
    @State private var isRulerModeActive = false
    @State private var liveActionMessage: String?
    @State private var isRadialMenuOpen = false

    private var isFocusModeActive: Bool {
        captureState.isFocusActive
    }

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
                    .sheet(item: $activeCaptureSheet) { sheet in
                        switch sheet {
                        case .waterPressureTest:
                            WaterSupplyTestSheet(viewModel: viewModel, visitID: visitID)
                        case .socketTester:
                            SocketSeeTestSheet { result in
                                saveSocketTesterResult(result)
                            }
                        }
                    }
                    .alert("Focused scan will end the room scan", isPresented: $isPresentingFocusWarning) {
                        Button("Cancel", role: .cancel) {}
                        Button("Start Focused Scan", role: .destructive) {
                            startFocusMode()
                        }
                    } message: {
                        Text("Focused scan switches from whole-room capture to local detail capture. Use it when you are ready to stop extending the current room scan.")
                    }
            } else {
                ContentUnavailableView("Property not found", systemImage: "exclamationmark.triangle")
            }
        }
    }

    @ViewBuilder
    private func cameraFirstCapture(visit: Visit) -> some View {
        liveCaptureSurface(visit: visit)
            .onAppear {
                resetTransientCaptureUI()
                requestSpatialSessionStart()
            }
            .onDisappear {
                teardownTransientCaptureUI()
            }
    }

    private func liveCaptureSurface(visit: Visit) -> some View {
        ZStack {
            LiveSpatialCaptureView(
                progress: $scanProgress,
                aim: $spatialAim,
                snapshotRequestID: snapshotRequestID,
                isScanning: spatialSession.status == .scanning,
                captureState: captureState,
                onSnapshotCaptured: saveCapturedFrame
            )
                .id(spatialSession.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            LiveSurveyCoverageOverlay(
                capturedSurfaceCount: scanProgress.capturedSurfaceCount,
                isFocusModeActive: isFocusModeActive,
                isRulerModeActive: isRulerModeActive,
                hasRulerStart: rulerStartPosition != nil
            )

            LinearGradient(
                colors: [.black.opacity(0.42), .clear, .black.opacity(0.66)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                LiveCaptureMiniTimeline(
                    visit: visit,
                    scanProgress: scanProgress
                )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            LiveCaptureSideMenus(
                activeDrawer: $activeSideDrawer,
                onNextRoom: finishRoomAndStartNextRoom,
                onFocus: requestFocusMode,
                onWater: { activeCaptureSheet = .waterPressureTest },
                onElectrical: { activeCaptureSheet = .socketTester },
                onMeasurement: beginRulerMeasurement,
                onSafety: { createLiveEvidence(.safety) },
                onReview: pauseForReview
            )

            if let liveActionMessage {
                VStack {
                    Spacer()
                    Text(liveActionMessage)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.54), in: Capsule())
                        .padding(.bottom, 116)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .padding(.horizontal, 16)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Spacer(minLength: 20)
                LiveCaptureStatusBar(
                    reference: visit.reference,
                    sessionStatus: surveyStatusTitle,
                    sessionColor: sessionStatusColor,
                    placementLabel: surveyConfidenceLabel,
                    onEnd: leaveSurvey
                )
                .frame(maxWidth: 320)
                Spacer(minLength: 20)
            }
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            LiveCaptureControlBar(
                isRulerModeActive: isRulerModeActive,
                isRadialMenuOpen: $isRadialMenuOpen,
                onCapture: capAction,
                onNextRoom: finishRoomAndStartNextRoom,
                onFocus: requestFocusMode,
                onWater: { activeCaptureSheet = .waterPressureTest },
                onElectrical: { activeCaptureSheet = .socketTester },
                onMeasurement: beginRulerMeasurement,
                onSafety: { createLiveEvidence(.safety) },
                onReview: pauseForReview
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .onChange(of: scanProgress) { _, _ in
            syncPlacementStateForSession()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private var currentPlacementMetadata: SpatialPlacement? {
        guard spatialSession.status == .scanning || spatialSession.status == .paused else {
            return nil
        }
        return livePlacementState.currentPlacement
    }

    private var surveyStatusTitle: String {
        if captureState.isFocusActive {
            return "Focus Mode"
        }
        return spatialSession.status == .scanning ? "Survey" : spatialSession.status.title
    }

    private var surveyConfidenceLabel: String {
        if captureState.isFocusActive {
            return "Capturing local detail"
        }
        if scanProgress.captureLabel == "Room understood" {
            return "Room understood"
        }
        if scanProgress.hasGeometry {
            return "Building room outline"
        }
        return "Move around for more detail"
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
        captureState = scanProgress.captureLabel == "Room understood" ? .roomUnderstood : .roomScanning
        recordingService.startRecording(visitID: visitID)
        syncPlacementStateForSession()
    }

    private func requestSpatialSessionStart() {
        guard !didRequestSpatialStart else { return }
        didRequestSpatialStart = true

        Task { @MainActor in
            await Task.yield()
            guard didRequestSpatialStart else { return }
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
        captureState = .idle
        recordingService.stopRecording()
        livePlacementState = .unavailable
    }

    private func resetTransientCaptureUI() {
        capturedEvidenceComponentID = nil
        snapshotRequestID = nil
        livePlacementState = .unavailable
        scanProgress = .empty
        spatialAim = .empty
        rulerStartPosition = nil
        isRulerModeActive = false
        liveActionMessage = nil
    }

    private func teardownTransientCaptureUI() {
        didRequestSpatialStart = false
        spatialSession.status = .notStarted
        spatialSession.endedAt = nil
        capturedEvidenceComponentID = nil
        snapshotRequestID = nil
        scanProgress = .empty
        spatialAim = .empty
        livePlacementState = .unavailable
        rulerStartPosition = nil
        isRulerModeActive = false
        liveActionMessage = nil
        captureState = .idle
        recordingService.stopRecording()
    }

    private func syncPlacementStateForSession() {
        guard spatialSession.status == .scanning else {
            livePlacementState = .unavailable
            return
        }
        if !captureState.isFocusActive {
            captureState = scanProgress.captureLabel == "Room understood" ? .roomUnderstood : .roomScanning
        } else if captureState == .focusPreparing, scanProgress.capturePath == .focusPointCloud {
            captureState = scanProgress.hasGeometry ? .focusCapturing : .focusPreparing
        } else if captureState == .focusCapturing, scanProgress.captureLabel == "Local detail captured" {
            captureState = .focusCaptured
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

    @discardableResult
    private func createLiveEvidence(
        _ kind: LiveCaptureEvidenceKind,
        photoData: Data? = nil,
        geometryCaptureMode: GeometryCaptureMode? = nil,
        geometryDetailLevel: GeometryDetailLevel? = nil,
        geometrySource: GeometrySource? = nil
    ) -> UUID? {
        let geometryMode = geometryCaptureMode ?? defaultGeometryCaptureMode(for: kind)
        let detailLevel = geometryDetailLevel ?? defaultGeometryDetailLevel(for: geometryMode)
        let source = geometrySource ?? defaultGeometrySource(for: geometryMode)
        let componentID = viewModel.addLiveCaptureEvidence(
            to: visitID,
            kind: kind,
            placement: currentPlacementMetadata,
            photoData: photoData,
            scanSessionID: spatialSession.id,
            cameraFrameReference: photoData == nil ? nil : "current-frame",
            geometryAnchorID: currentPlacementMetadata?.anchorID,
            positionLabel: scanProgress.hasGeometry ? scanProgress.captureLabel : surveyConfidenceLabel,
            geometryCaptureMode: geometryMode,
            geometryDetailLevel: detailLevel,
            geometrySource: source,
            geometryConfidence: scanProgress.confidence,
            devicePosition: spatialAim.devicePosition,
            targetPosition: spatialAim.targetPosition
        )
        capturedEvidenceComponentID = componentID

        let hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = kind == .safety ? .heavy : .medium
        UIImpactFeedbackGenerator(style: hapticStyle).impactOccurred()
        return componentID
    }

    private func requestFocusMode() {
        if captureState.isFocusActive {
            endFocusMode()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            isPresentingFocusWarning = true
        }
    }

    private func startFocusMode() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            captureState = .focusPreparing
            scanProgress = LiveSpatialScanProgress(capturePath: .focusPointCloud)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    private func capAction() {
        if isRulerModeActive {
            placeGeometryRuler()
            return
        }
        snapshotRequestID = UUID()
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    private func saveCapturedFrame(_ data: Data) {
        createLiveEvidence(.photo, photoData: data)
    }

    private func finishRoomAndStartNextRoom() {
        let roomNumber = ((visit?.rooms.count ?? 0) + 1)
        viewModel.addRoom(to: visitID, named: "Room \(roomNumber)", placement: currentPlacementMetadata)
        createLiveEvidence(
            .mark,
            geometryCaptureMode: .manual,
            geometryDetailLevel: .room,
            geometrySource: .userMarked
        )
        rulerStartPosition = nil
        isRulerModeActive = false
        spatialSession.id = UUID()
        scanProgress = .empty
        spatialAim = .empty
        livePlacementState = .unavailable
        captureState = .roomScanning
        showLiveActionMessage("Room \(roomNumber) finished. New room scan started")
    }

    private func beginRulerMeasurement() {
        isRulerModeActive = true
        showLiveActionMessage(rulerStartPosition == nil ? "Ruler active. Tap capture to place start" : "Tap capture to place end")
    }

    private func placeGeometryRuler() {
        let targetPosition = spatialAim.targetPosition ?? livePlacementState.lastKnownPosition ?? SpatialPosition(x: 0, y: 0, z: 0)

        guard let startPosition = rulerStartPosition else {
            rulerStartPosition = targetPosition
            showLiveActionMessage("Ruler start placed. Aim and tap capture for end")
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return
        }

        let distance = startPosition.distance(to: targetPosition)
        let componentID = createLiveEvidence(
            .measurement,
            geometryCaptureMode: .manual,
            geometryDetailLevel: .component,
            geometrySource: .userMarked
        )
        if let componentID {
            let distanceText = String(format: "%.2f m", distance)
            viewModel.updateComponentAttribute(distanceText, for: "rulerDistance", componentID: componentID, visitID: visitID)
            viewModel.updateComponentAttribute(startPosition.coordinateSummary, for: "rulerStart", componentID: componentID, visitID: visitID)
            viewModel.updateComponentAttribute(targetPosition.coordinateSummary, for: "rulerEnd", componentID: componentID, visitID: visitID)
            viewModel.updateComponentAttribute("Ruler measurement: \(distanceText)", for: "transcriptSnippet", componentID: componentID, visitID: visitID)
            viewModel.updateComponentAttribute("Geometry ruler", for: "suggestedLabel", componentID: componentID, visitID: visitID)
        }
        rulerStartPosition = nil
        isRulerModeActive = false
        showLiveActionMessage("Ruler saved: \(String(format: "%.2f m", distance))")
    }

    private func saveSocketTesterResult(_ result: SocketSeeTestResult) {
        guard let componentID = createLiveEvidence(
            .electrical,
            geometryCaptureMode: .manual,
            geometryDetailLevel: .component,
            geometrySource: .userMarked
        ) else { return }

        viewModel.updateComponentAttribute("Socket & See", for: "socketTester", componentID: componentID, visitID: visitID)
        viewModel.updateComponentAttribute(result.wiringStatus.rawValue, for: "socketWiringStatus", componentID: componentID, visitID: visitID)
        viewModel.updateComponentAttribute(result.rmsVoltageBand.rawValue, for: "socketRMSVoltage", componentID: componentID, visitID: visitID)
        viewModel.updateComponentAttribute(result.earthLoopImpedanceBand.rawValue, for: "socketEarthLoopImpedance", componentID: componentID, visitID: visitID)
        viewModel.updateComponentAttribute(result.loopTestStatus.rawValue, for: "socketLoopTestStatus", componentID: componentID, visitID: visitID)
        viewModel.updateComponentAttribute(result.notes, for: "socketTestNotes", componentID: componentID, visitID: visitID)
        viewModel.updateComponentAttribute(result.reviewSummary, for: "transcriptSnippet", componentID: componentID, visitID: visitID)
        viewModel.updateComponentAttribute("Socket & See test", for: "suggestedLabel", componentID: componentID, visitID: visitID)
        showLiveActionMessage("Socket & See result saved")
    }

    private func showLiveActionMessage(_ message: String) {
        withAnimation(.snappy) {
            liveActionMessage = message
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if liveActionMessage == message {
                withAnimation(.snappy) {
                    liveActionMessage = nil
                }
            }
        }
    }

    private func endFocusMode() {
        withAnimation(.easeOut(duration: 0.16)) {
            captureState = .focusEnding
        }
        createLiveEvidence(
            .mark,
            geometryCaptureMode: .focusPointCloud,
            geometryDetailLevel: .local,
            geometrySource: .arkitPointCloud
        )
        scanProgress = LiveSpatialScanProgress(capturePath: .roomPlan)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            captureState = .roomScanning
        }
    }

    private func defaultGeometryCaptureMode(for kind: LiveCaptureEvidenceKind) -> GeometryCaptureMode {
        if isFocusModeActive {
            return .focusPointCloud
        }
        if scanProgress.capturePath == .roomPlan, scanProgress.hasGeometry {
            return .roomPlan
        }
        switch kind {
        case .photo, .voice:
            return .photoOnly
        case .mark, .safety, .measurement, .gas, .water, .electrical:
            return .manual
        }
    }

    private func defaultGeometryDetailLevel(for mode: GeometryCaptureMode) -> GeometryDetailLevel {
        switch mode {
        case .roomPlan:
            return .room
        case .focusPointCloud:
            return .local
        case .photoOnly, .manual:
            return .component
        }
    }

    private func defaultGeometrySource(for mode: GeometryCaptureMode) -> GeometrySource {
        switch mode {
        case .roomPlan:
            return .roomPlan
        case .focusPointCloud:
            return .arkitPointCloud
        case .photoOnly, .manual:
            return .userMarked
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
        teardownTransientCaptureUI()
        dismiss()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func resumeSurvey() {
        isPresentingReview = false
        requestSpatialSessionStart()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

private struct LiveCaptureStatusBar: View {
    let reference: String
    let sessionStatus: String
    let sessionColor: Color
    let placementLabel: String
    let onEnd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Text(reference)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Spacer(minLength: 8)

                endButton
            }

            HStack(alignment: .center, spacing: 8) {
                Circle()
                    .fill(sessionColor)
                    .frame(width: 9, height: 9)
                Text(sessionStatus)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer(minLength: 8)
                Text(placementLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
            }
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var endButton: some View {
        Button(action: onEnd) {
            Image(systemName: "xmark")
                .font(.caption.weight(.bold))
                .frame(width: 34, height: 34)
                .background(Color.black.opacity(0.32), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                .foregroundStyle(.white)
        }
        .accessibilityLabel("End survey")
    }
}

private struct LiveSurveyCoverageOverlay: View {
    let capturedSurfaceCount: Int
    let isFocusModeActive: Bool
    let isRulerModeActive: Bool
    let hasRulerStart: Bool

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                if isFocusModeActive {
                    focusReticle(in: proxy.size)
                }
                if isRulerModeActive {
                    rulerReticle(in: proxy.size)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func rulerReticle(in size: CGSize) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: center.x - 58, y: center.y))
                path.addLine(to: CGPoint(x: center.x + 58, y: center.y))
                path.move(to: CGPoint(x: center.x, y: center.y - 58))
                path.addLine(to: CGPoint(x: center.x, y: center.y + 58))
            }
            .stroke(Color.white.opacity(0.92), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 5]))

            Circle()
                .stroke(hasRulerStart ? Color.green : Color.white, lineWidth: 3)
                .frame(width: 92, height: 92)
                .position(center)

            Text(hasRulerStart ? "END" : "START")
                .font(.caption.weight(.bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(hasRulerStart ? Color.green : Color.white, in: Capsule())
                .position(x: center.x, y: center.y - 66)
        }
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

private enum LiveCaptureSheet: Identifiable {
    case waterPressureTest
    case socketTester

    var id: String {
        switch self {
        case .waterPressureTest:
            return "water-pressure-test"
        case .socketTester:
            return "socket-tester"
        }
    }
}

private enum LiveCaptureSideDrawer: Equatable {
    case survey
    case markers
}

private struct LiveCaptureSideMenus: View {
    @Binding var activeDrawer: LiveCaptureSideDrawer?
    let onNextRoom: () -> Void
    let onFocus: () -> Void
    let onWater: () -> Void
    let onElectrical: () -> Void
    let onMeasurement: () -> Void
    let onSafety: () -> Void
    let onReview: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top + 104
            let safeBottom = proxy.safeAreaInsets.bottom + 126

            ZStack {
                if activeDrawer != nil {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.snappy) {
                                activeDrawer = nil
                            }
                        }
                        .accessibilityHidden(true)
                }

                HStack {
                    sideEdgeHandle(
                        side: .survey,
                        systemImage: "chevron.right",
                        alignment: .leading,
                        openOffset: 232
                    )
                    Spacer()
                    sideEdgeHandle(
                        side: .markers,
                        systemImage: "chevron.left",
                        alignment: .trailing,
                        openOffset: -232
                    )
                }
                .padding(.top, safeTop)
                .padding(.bottom, safeBottom)

                sideDrawer(
                    side: .survey,
                    title: "Survey",
                    subtitle: "Move through the property",
                    alignment: .leading,
                    items: [
                        LiveCaptureMenuItem(title: "Next Room", systemImage: "rectangle.stack.badge.plus", tint: .white, action: onNextRoom),
                        LiveCaptureMenuItem(title: "Focused Scan", systemImage: "scope", tint: .yellow, action: onFocus),
                        LiveCaptureMenuItem(title: "Review Capture", systemImage: "list.bullet.rectangle", tint: .white, accessibilityLabel: "Review capture", action: onReview)
                    ]
                )
                .padding(.top, safeTop)
                .padding(.bottom, safeBottom)

                sideDrawer(
                    side: .markers,
                    title: "Markers",
                    subtitle: "Evidence only, no interruption",
                    alignment: .trailing,
                    items: [
                        LiveCaptureMenuItem(title: "Water Pressure Test", systemImage: "drop.fill", tint: .cyan, accessibilityLabel: "Water pressure test results", action: onWater),
                        LiveCaptureMenuItem(title: "Socket & See", systemImage: "bolt.fill", tint: .yellow, accessibilityLabel: "Socket and See test results", action: onElectrical),
                        LiveCaptureMenuItem(title: "Place Ruler", systemImage: "ruler", tint: .white, accessibilityLabel: "Place ruler on geometry", action: onMeasurement),
                        LiveCaptureMenuItem(title: "Safety Issue", systemImage: "exclamationmark.triangle.fill", tint: .red, accessibilityLabel: "Safety hazard", action: onSafety)
                    ]
                )
                .padding(.top, safeTop)
                .padding(.bottom, safeBottom)

                HStack {
                    edgeSwipeZone(side: .survey)
                    Spacer()
                    edgeSwipeZone(side: .markers)
                }
            }
        }
        .ignoresSafeArea(.container, edges: [.leading, .trailing])
    }

    private func sideDrawer(
        side: LiveCaptureSideDrawer,
        title: String,
        subtitle: String,
        alignment: HorizontalAlignment,
        items: [LiveCaptureMenuItem]
    ) -> some View {
        HStack {
            if side == .markers {
                Spacer()
            }
            VStack(alignment: alignment, spacing: 12) {
                VStack(alignment: alignment, spacing: 3) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: side == .survey ? .leading : .trailing)

                VStack(spacing: 8) {
                    ForEach(items) { item in
                        Button {
                            item.action()
                            withAnimation(.snappy) {
                                activeDrawer = nil
                            }
                        } label: {
                            HStack(spacing: 10) {
                                if side == .markers {
                                    Spacer(minLength: 0)
                                }
                                Image(systemName: item.systemImage)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(item.tint)
                                    .frame(width: 24)
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                if side == .survey {
                                    Spacer(minLength: 0)
                                }
                            }
                            .frame(height: 42)
                            .padding(.horizontal, 12)
                            .background(.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.accessibilityLabel ?? item.title)
                    }
                }
            }
            .frame(width: 224)
            .padding(12)
            .background(.black.opacity(0.64), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
            .offset(x: drawerOffset(for: side))
            .animation(.snappy, value: activeDrawer)
            .accessibilityElement(children: .contain)

            if side == .survey {
                Spacer()
            }
        }
        .padding(.horizontal, 10)
    }

    private func sideEdgeHandle(
        side: LiveCaptureSideDrawer,
        systemImage: String,
        alignment: HorizontalAlignment,
        openOffset: CGFloat
    ) -> some View {
        VStack {
            Spacer()
            Button {
                withAnimation(.snappy) {
                    activeDrawer = activeDrawer == side ? nil : side
                }
            } label: {
                Image(systemName: systemImage)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 64)
                    .background(.black.opacity(0.38), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(side == .survey ? "Open survey menu" : "Open marker menu")
            .offset(x: activeDrawer == side ? openOffset : 0)
            .animation(.snappy, value: activeDrawer)
            Spacer()
        }
        .frame(width: 36)
    }

    private func edgeSwipeZone(side: LiveCaptureSideDrawer) -> some View {
        Rectangle()
            .fill(.clear)
            .contentShape(Rectangle())
            .frame(width: 34)
            .gesture(
                DragGesture(minimumDistance: 18)
                    .onEnded { value in
                        let isOpeningSurvey = side == .survey && value.translation.width > 28
                        let isOpeningMarkers = side == .markers && value.translation.width < -28
                        if isOpeningSurvey || isOpeningMarkers {
                            withAnimation(.snappy) {
                                activeDrawer = side
                            }
                        }
                    }
            )
            .accessibilityHidden(true)
    }

    private func drawerOffset(for side: LiveCaptureSideDrawer) -> CGFloat {
        if activeDrawer == side {
            return 0
        }
        return side == .survey ? -270 : 270
    }
}

private struct LiveCaptureMenuItem: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let tint: Color
    var accessibilityLabel: String? = nil
    let action: () -> Void
}

private struct SocketSeeTestResult {
    var wiringStatus: SocketSeeWiringStatus
    var rmsVoltageBand: SocketSeeRMSVoltageBand
    var earthLoopImpedanceBand: SocketSeeEarthLoopImpedanceBand
    var loopTestStatus: SocketSeeLoopTestStatus
    var notes: String

    var reviewSummary: String {
        [
            "Socket & See",
            "Wiring: \(wiringStatus.title)",
            "RMS: \(rmsVoltageBand.title)",
            "Earth loop: \(earthLoopImpedanceBand.title)",
            "Loop test: \(loopTestStatus.title)",
            notes.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " | ")
    }
}

private enum SocketSeeWiringStatus: String, CaseIterable, Identifiable {
    case correct = "Correct"
    case liveEarthReverse = "L-E Reverse"
    case liveNeutralReverse = "L-N Reverse"
    case earthFault = "E Fault"
    case liveFault = "L Fault"
    case unknown = "Unknown"

    var id: String { rawValue }
    var title: String { rawValue }
}

private enum SocketSeeRMSVoltageBand: String, CaseIterable, Identifiable {
    case low = "<207 V"
    case valid = "207-253 V"
    case high = ">253 V"
    case unknown = "Unknown"

    var id: String { rawValue }
    var title: String { rawValue }
}

private enum SocketSeeEarthLoopImpedanceBand: String, CaseIterable, Identifiable {
    case underOne = "<1 ohm"
    case underTwo = "<2 ohm"
    case underHundred = "<100 ohm"
    case underTwoHundred = "<200 ohm"
    case overTwoHundred = ">200 ohm"
    case unknown = "Unknown"

    var id: String { rawValue }
    var title: String { rawValue }
}

private enum SocketSeeLoopTestStatus: String, CaseIterable, Identifiable {
    case valid = "Valid"
    case notTested = "Not tested"
    case failed = "Failed"
    case unknown = "Unknown"

    var id: String { rawValue }
    var title: String { rawValue }
}

private struct SocketSeeTestSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (SocketSeeTestResult) -> Void

    @State private var wiringStatus: SocketSeeWiringStatus = .correct
    @State private var rmsVoltageBand: SocketSeeRMSVoltageBand = .valid
    @State private var earthLoopImpedanceBand: SocketSeeEarthLoopImpedanceBand = .underOne
    @State private var loopTestStatus: SocketSeeLoopTestStatus = .valid
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Socket & See") {
                    Picker("Wiring", selection: $wiringStatus) {
                        ForEach(SocketSeeWiringStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    Picker("RMS voltage", selection: $rmsVoltageBand) {
                        ForEach(SocketSeeRMSVoltageBand.allCases) { band in
                            Text(band.title).tag(band)
                        }
                    }
                    Picker("Earth loop impedance", selection: $earthLoopImpedanceBand) {
                        ForEach(SocketSeeEarthLoopImpedanceBand.allCases) { band in
                            Text(band.title).tag(band)
                        }
                    }
                    Picker("Loop test", selection: $loopTestStatus) {
                        ForEach(SocketSeeLoopTestStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Outlet, room, or tester note", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("Socket & See")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            SocketSeeTestResult(
                                wiringStatus: wiringStatus,
                                rmsVoltageBand: rmsVoltageBand,
                                earthLoopImpedanceBand: earthLoopImpedanceBand,
                                loopTestStatus: loopTestStatus,
                                notes: notes
                            )
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}

private extension SpatialPosition {
    func distance(to other: SpatialPosition) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        let dz = z - other.z
        return (dx * dx + dy * dy + dz * dz).squareRoot()
    }

    var coordinateSummary: String {
        String(format: "%.3f, %.3f, %.3f", x, y, z)
    }
}

private struct LiveCaptureControlBar: View {
    let isRulerModeActive: Bool
    @Binding var isRadialMenuOpen: Bool
    let onCapture: () -> Void
    let onNextRoom: () -> Void
    let onFocus: () -> Void
    let onWater: () -> Void
    let onElectrical: () -> Void
    let onMeasurement: () -> Void
    let onSafety: () -> Void
    let onReview: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 18) {
            Spacer()

            LiveCaptureRadialDial(
                isOpen: $isRadialMenuOpen,
                actions: [
                    LiveCaptureDialAction(title: "Finish Room", systemImage: "rectangle.stack.badge.plus", tint: .white, action: onNextRoom),
                    LiveCaptureDialAction(title: "Focus", systemImage: "scope", tint: .yellow, action: onFocus),
                    LiveCaptureDialAction(title: "Water", systemImage: "drop.fill", tint: .cyan, action: onWater),
                    LiveCaptureDialAction(title: "Socket", systemImage: "bolt.fill", tint: .yellow, action: onElectrical),
                    LiveCaptureDialAction(title: "Ruler", systemImage: "ruler", tint: .white, action: onMeasurement),
                    LiveCaptureDialAction(title: "Safety", systemImage: "exclamationmark.triangle.fill", tint: .red, action: onSafety),
                    LiveCaptureDialAction(title: "Review", systemImage: "list.bullet.rectangle", tint: .white, action: onReview)
                ]
            )

            Button(action: onCapture) {
                Circle()
                    .fill(isRulerModeActive ? Color.white : Color.yellow)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.85), lineWidth: 2)
                    )
                    .overlay {
                        if isRulerModeActive {
                            Image(systemName: "ruler")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.black)
                        }
                    }
                    .shadow(color: .black.opacity(0.28), radius: 10, y: 4)
                    .frame(width: 86, height: 86)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRulerModeActive ? "Place ruler point" : "Capture evidence")
            Spacer()
        }
    }
}

private struct LiveCaptureDialAction: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void
}

private struct LiveCaptureRadialDial: View {
    @Binding var isOpen: Bool
    let actions: [LiveCaptureDialAction]

    @State private var dragRotation: Angle = .zero

    var body: some View {
        ZStack {
            if isOpen {
                ForEach(Array(actions.enumerated()), id: \.element.id) { index, item in
                    Button {
                        item.action()
                        withAnimation(.snappy) {
                            isOpen = false
                        }
                    } label: {
                        Image(systemName: item.systemImage)
                            .font(.callout.weight(.bold))
                            .foregroundStyle(item.tint)
                            .frame(width: 42, height: 42)
                            .background(.black.opacity(0.62), in: Circle())
                            .overlay(Circle().stroke(item.tint.opacity(0.42), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                    .offset(offset(for: index))
                    .transition(.scale.combined(with: .opacity))
                }
            }

            Button {
                withAnimation(.snappy) {
                    isOpen.toggle()
                }
            } label: {
                Image(systemName: "dial.low")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(.black.opacity(0.46), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 1))
                    .rotationEffect(dragRotation)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Capture action dial")
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        dragRotation = Angle(degrees: Double(value.translation.width + value.translation.height))
                    }
                    .onEnded { _ in
                        withAnimation(.snappy) {
                            isOpen = true
                            dragRotation = .zero
                        }
                    }
            )
        }
        .frame(width: 78, height: 86)
        .animation(.snappy, value: isOpen)
    }

    private func offset(for index: Int) -> CGSize {
        let total = max(actions.count - 1, 1)
        let start = -170.0
        let end = -20.0
        let angle = (start + ((end - start) / Double(total)) * Double(index)) * .pi / 180
        let radius = 104.0
        return CGSize(width: cos(angle) * radius, height: sin(angle) * radius)
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
                Text(scanProgress.hasGeometry ? scanProgress.captureLabel : "Move around for more detail")
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
            return "needs another angle"
        }
        if spatialContext.localizedCaseInsensitiveContains("geometry") ||
            spatialContext.localizedCaseInsensitiveContains("anchor") {
            return "area linked"
        }
        return "evidence linked"
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
