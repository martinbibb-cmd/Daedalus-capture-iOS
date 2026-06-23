import SwiftUI

struct SurveySectionCaptureView: View {
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID

    @StateObject private var recorder = VoiceNoteRecorder()

    @State private var selectedTargetIndex = 0
    @State private var selectedRoomID: UUID?

    @State private var pendingCaptureDestination: CaptureDestination?
    @State private var annotationDestination: CaptureDestination?
    @State private var annotationText = ""

    @State private var isPresentingCamera = false
    @State private var isPresentingAnnotation = false
    @State private var isShowingTargetWheel = false
    @State private var isShowingProgressDrawer = false

    @State private var didLongPressRecord = false
    @State private var isNarrativeCaptureActive = false
    @State private var didAutoLaunchCamera = false

    @State private var componentEditorID: UUID?
    @State private var roomEditorID: UUID?
    @State private var isPresentingComponentEditor = false
    @State private var isPresentingRoomEditor = false

    private static let primaryTargets: [CaptureTarget] = [
        .boiler,
        .flue,
        .controls,
        .cylinder,
        .meter,
        .radiator,
        .room,
        .general
    ]

    private var visit: Visit? {
        viewModel.visit(id: visitID)
    }

    private var selectedTarget: CaptureTarget {
        let index = min(max(selectedTargetIndex, 0), Self.primaryTargets.count - 1)
        return Self.primaryTargets[index]
    }

    private var selectedRoomName: String {
        guard let visit,
              let room = visit.rooms.first(where: { $0.id == selectedRoomID }) else {
            return "No scanned area selected"
        }
        return room.name
    }

    var body: some View {
        Group {
            if visit != nil {
                captureShell
            } else {
                ContentUnavailableView("Property not found", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $isPresentingComponentEditor) {
            if let componentEditorID {
                ComponentDetailView(viewModel: viewModel, visitID: visitID, componentID: componentEditorID)
            }
        }
        .navigationDestination(isPresented: $isPresentingRoomEditor) {
            if let roomEditorID {
                RoomDetailView(viewModel: viewModel, visitID: visitID, roomID: roomEditorID)
            }
        }
        .fullScreenCover(isPresented: $isPresentingCamera) {
            CameraCaptureView { imageData in
                guard let destination = pendingCaptureDestination else { return }
                attachPhoto(imageData, to: destination)
                annotationDestination = destination
                annotationText = ""
                isPresentingAnnotation = true
                pendingCaptureDestination = nil
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isPresentingAnnotation) {
            CaptureAnnotationSheet(
                targetLabel: selectedTarget.displayName,
                locationLabel: selectedRoomName,
                text: $annotationText,
                isRecording: recorder.isRecording,
                onToggleVoice: toggleAnnotationVoice,
                onSaveText: saveAnnotationText,
                onDone: {
                    if recorder.isRecording {
                        _ = stopAnnotationVoiceAndAttach()
                    }
                    isPresentingAnnotation = false
                    annotationDestination = nil
                    annotationText = ""
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $isShowingTargetWheel) {
            targetWheelSheet
        }
        .sheet(isPresented: $isShowingProgressDrawer) {
            progressDrawerSheet
        }
        .onAppear {
            syncSelectedRoom()
            if !didAutoLaunchCamera {
                didAutoLaunchCamera = true
                launchPhotoCapture()
            }
        }
        .onChange(of: visit?.rooms.map(\.id) ?? []) { _, _ in
            syncSelectedRoom()
        }
        .onChange(of: recorder.errorMessage) { _, newValue in
            if let newValue {
                viewModel.errorMessage = newValue
            }
        }
        .onDisappear {
            if recorder.isRecording {
                _ = recorder.stopRecording()
            }
        }
    }

    private var captureShell: some View {
        ZStack {
            Rectangle()
                .fill(.black)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topOverlay
                Spacer()
                bottomOverlay
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 18)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded(handleSwipe)
        )
    }

    private var topOverlay: some View {
        VStack(spacing: 8) {
            Text(selectedTarget.displayName)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.18))
                .clipShape(Capsule())

            Text("Location: \(selectedRoomName)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.82))
        }
    }

    private var bottomOverlay: some View {
        VStack(spacing: 14) {
            Text("Swipe ←/→ target  •  Swipe ↑ type wheel  •  Swipe ↓ progress")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.72))

            Button(action: {
                if didLongPressRecord {
                    didLongPressRecord = false
                    return
                }
                launchPhotoCapture()
            }) {
                Circle()
                    .strokeBorder(Color.white, lineWidth: 4)
                    .background(Circle().fill(Color.white.opacity(0.14)))
                    .frame(width: 88, height: 88)
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 66, height: 66)
                    )
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.35)
                    .onChanged { _ in
                        beginNarrativeCaptureIfNeeded()
                    }
                    .onEnded { _ in
                        completeNarrativeCaptureIfNeeded()
                    }
            )
            .buttonStyle(.plain)

            Text(isNarrativeCaptureActive ? "Recording narrative… release to save" : "Tap: photo  •  Hold: narrative (voice fallback)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.86))
        }
    }

    private var targetWheelSheet: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Picker("Capture target", selection: $selectedTargetIndex) {
                    ForEach(Array(Self.primaryTargets.enumerated()), id: \.offset) { index, target in
                        Text(target.displayName).tag(index)
                    }
                }
                .pickerStyle(.wheel)

                Button("Use Target") {
                    isShowingTargetWheel = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Object / Type")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var progressDrawerSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                List {
                    Section("Capture Progress") {
                        ForEach(Self.primaryTargets) { target in
                            HStack {
                                Text(target.displayName)
                                Spacer()
                                Text("\(evidenceCount(for: target))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section("Current Context") {
                        HStack {
                            Text("Target")
                            Spacer()
                            Text(selectedTarget.displayName)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Location")
                            Spacer()
                            Text(selectedRoomName)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button("Review Selected Target") {
                    isShowingProgressDrawer = false
                    openSelectedTargetEditor()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func handleSwipe(_ value: DragGesture.Value) {
        let width = value.translation.width
        let height = value.translation.height

        if abs(width) > abs(height), abs(width) > 36 {
            if width < 0 {
                selectedTargetIndex = min(selectedTargetIndex + 1, Self.primaryTargets.count - 1)
            } else {
                selectedTargetIndex = max(selectedTargetIndex - 1, 0)
            }
            return
        }

        if abs(height) > abs(width), abs(height) > 42 {
            if height < 0 {
                isShowingTargetWheel = true
            } else {
                isShowingProgressDrawer = true
            }
        }
    }

    private func syncSelectedRoom() {
        guard let visit else {
            selectedRoomID = nil
            return
        }
        if let selectedRoomID,
           visit.rooms.contains(where: { $0.id == selectedRoomID }) {
            return
        }
        selectedRoomID = visit.rooms.first?.id
    }

    private func resolveCaptureDestination() -> CaptureDestination? {
        switch selectedTarget {
        case .room:
            let roomID = selectedRoomID ?? viewModel.ensureScannedArea(in: visitID)
            selectedRoomID = roomID
            guard let roomID else { return nil }
            return .room(roomID)
        default:
            guard let kind = selectedTarget.componentKind,
                  let componentID = viewModel.ensureComponent(for: kind, visitID: visitID) else {
                return nil
            }
            applyLocationContextIfAvailable(toComponent: componentID)
            return .component(componentID)
        }
    }

    private func launchPhotoCapture() {
        guard let destination = resolveCaptureDestination() else { return }
        pendingCaptureDestination = destination
        isPresentingCamera = true
    }

    private func beginNarrativeCaptureIfNeeded() {
        guard !isNarrativeCaptureActive,
              !recorder.isRecording,
              let destination = resolveCaptureDestination() else { return }

        guard let voiceURL = voiceURL(for: destination) else { return }
        annotationDestination = destination
        didLongPressRecord = true
        isNarrativeCaptureActive = true
        recorder.startRecording(to: voiceURL)
    }

    private func completeNarrativeCaptureIfNeeded() {
        guard isNarrativeCaptureActive else { return }
        isNarrativeCaptureActive = false

        guard recorder.isRecording,
              let destination = annotationDestination,
              let voiceURL = recorder.stopRecording() else {
            annotationDestination = nil
            return
        }

        attachVoice(url: voiceURL, to: destination)
        isPresentingAnnotation = true
        annotationText = ""
    }

    private func toggleAnnotationVoice() {
        guard let destination = annotationDestination else { return }
        if recorder.isRecording {
            _ = stopAnnotationVoiceAndAttach()
            return
        }
        guard let voiceURL = voiceURL(for: destination) else { return }
        recorder.startRecording(to: voiceURL)
    }

    private func stopAnnotationVoiceAndAttach() -> Bool {
        guard recorder.isRecording,
              let destination = annotationDestination,
              let voiceURL = recorder.stopRecording() else {
            return false
        }
        attachVoice(url: voiceURL, to: destination)
        return true
    }

    private func saveAnnotationText() {
        guard let destination = annotationDestination else { return }
        let trimmed = annotationText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch destination {
        case let .room(roomID):
            viewModel.attachTextNote(text: trimmed, to: roomID, in: visitID)
        case let .component(componentID):
            viewModel.attachTextNoteToComponent(text: trimmed, to: componentID, in: visitID)
        }

        annotationText = ""
    }

    private func voiceURL(for destination: CaptureDestination) -> URL? {
        switch destination {
        case let .room(roomID):
            return viewModel.prepareRoomVoiceNoteURL(for: roomID, in: visitID)
        case let .component(componentID):
            return viewModel.prepareComponentVoiceNoteURL(for: componentID, in: visitID)
        }
    }

    private func attachPhoto(_ data: Data, to destination: CaptureDestination) {
        switch destination {
        case let .room(roomID):
            viewModel.attachPhoto(data: data, to: roomID, in: visitID)
        case let .component(componentID):
            viewModel.attachPhoto(data: data, toComponent: componentID, in: visitID)
        }
    }

    private func attachVoice(url: URL, to destination: CaptureDestination) {
        switch destination {
        case let .room(roomID):
            viewModel.attachVoiceNoteToRoom(from: url, to: roomID, in: visitID)
        case let .component(componentID):
            viewModel.attachVoiceNoteToComponent(from: url, to: componentID, in: visitID)
        }
    }

    private func evidenceCount(for target: CaptureTarget) -> Int {
        guard let visit else { return 0 }
        if target == .room {
            if let selectedRoomID,
               let room = visit.rooms.first(where: { $0.id == selectedRoomID }) {
                return room.evidence.count
            }
            return visit.rooms.reduce(0) { $0 + $1.evidence.count }
        }
        guard let kind = target.componentKind else { return 0 }
        return visit.components
            .filter { $0.kind == kind && $0.captureMode == visit.captureMode }
            .reduce(0) { $0 + $1.evidence.count }
    }

    private func applyLocationContextIfAvailable(toComponent componentID: UUID) {
        guard let visit else { return }
        let roomID = selectedRoomID ?? visit.rooms.first?.id
        viewModel.applyAreaReference(toComponent: componentID, roomID: roomID, visitID: visitID)
    }

    private func openSelectedTargetEditor() {
        switch selectedTarget {
        case .room:
            if let roomID = selectedRoomID {
                roomEditorID = roomID
                isPresentingRoomEditor = true
            }
        default:
            guard let kind = selectedTarget.componentKind,
                  let componentID = viewModel.ensureComponent(for: kind, visitID: visitID) else {
                return
            }
            componentEditorID = componentID
            isPresentingComponentEditor = true
        }
    }
}

private enum CaptureTarget: String, CaseIterable, Identifiable {
    case boiler
    case flue
    case controls
    case cylinder
    case meter
    case radiator
    case room
    case general

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .boiler: return "Boiler"
        case .flue: return "Flue"
        case .controls: return "Controls"
        case .cylinder: return "Cylinder"
        case .meter: return "Meter"
        case .radiator: return "Radiator"
        case .room: return "Area"
        case .general: return "General"
        }
    }

    var componentKind: SystemComponentKind? {
        switch self {
        case .boiler: return .boiler
        case .flue: return .flue
        case .controls: return .controls
        case .cylinder: return .cylinder
        case .meter: return .gasMeter
        case .radiator: return .radiator
        case .general: return .other
        case .room: return nil
        }
    }
}

private enum CaptureDestination {
    case room(UUID)
    case component(UUID)
}

private struct CaptureAnnotationSheet: View {
    let targetLabel: String
    let locationLabel: String
    @Binding var text: String
    let isRecording: Bool
    let onToggleVoice: () -> Void
    let onSaveText: () -> Void
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Annotate \(targetLabel)")
                    .font(.headline)
                Text("Location: \(locationLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $text)
                    .frame(minHeight: 120)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    )

                HStack(spacing: 10) {
                    Button(isRecording ? "Stop Voice" : "Record Voice") {
                        onToggleVoice()
                    }
                    .buttonStyle(.bordered)

                    Button("Save Text") {
                        onSaveText()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Annotation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone()
                    }
                }
            }
        }
    }
}
