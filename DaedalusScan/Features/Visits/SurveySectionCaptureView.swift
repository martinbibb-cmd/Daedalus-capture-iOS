import SwiftUI

struct SurveySectionCaptureView: View {
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID
    @Binding var selectedKind: SystemComponentKind
    let sections: [CaptureSection]

    @StateObject private var recorder = VoiceNoteRecorder()
    @State private var isPresentingCamera = false
    @State private var isPresentingTextNote = false
    @State private var isPresentingStatusDialog = false
    @State private var isPresentingAdvancedDetails = false
    @State private var textNoteContent = ""
    @State private var activeComponentID: UUID?

    private var visit: Visit? {
        viewModel.visit(id: visitID)
    }

    private var components: [SystemComponent] {
        guard let visit else { return [] }
        return visit.components.filter { $0.kind == selectedKind && $0.captureMode == visit.captureMode }
    }

    private var evidenceCount: Int {
        components.reduce(0) { $0 + $1.evidence.count }
    }

    private var sectionStatus: SectionStatus {
        guard let visit else { return .notChecked }
        if visit.captureMode == .current {
            return visit.sectionStatuses[selectedKind] ?? .notChecked
        }
        return visit.proposedSectionStatuses[selectedKind] ?? .notChecked
    }

    private var statusBinding: Binding<SectionStatus> {
        Binding<SectionStatus>(
            get: { sectionStatus },
            set: { viewModel.setSectionStatus($0, for: selectedKind, visitID: visitID) }
        )
    }

    private var reviewLaterBinding: Binding<Bool> {
        Binding<Bool>(
            get: { components.contains(where: { $0.reviewStatus == .needsReview }) },
            set: { viewModel.setSectionReviewLater($0, for: selectedKind, visitID: visitID) }
        )
    }

    var body: some View {
        Group {
            if visit != nil {
                cockpitContent
            } else {
                Text("Section not found")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Camera-first layout

    private var cockpitContent: some View {
        ZStack(alignment: .top) {
            // Layer 0: full-screen live camera surface
            LiveCameraPreviewView()
                .ignoresSafeArea()
                .onTapGesture {
                    activeComponentID = viewModel.ensureComponent(for: selectedKind, visitID: visitID)
                    if activeComponentID != nil { isPresentingCamera = true }
                }

            // Layer 1: top compact overlay (section chips + status badge)
            topOverlay

            // Layer 2: bottom scrim + radial actions overlaid on camera
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                bottomOverlay
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle("Capture")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPresentingCamera) {
            CameraCaptureView { imageData in
                if let componentID = activeComponentID ?? viewModel.ensureComponent(for: selectedKind, visitID: visitID) {
                    viewModel.attachPhoto(data: imageData, toComponent: componentID, in: visitID)
                }
            }
        }
        .sheet(isPresented: $isPresentingTextNote) {
            SurveySectionTextNoteSheet(text: $textNoteContent) {
                if let componentID = activeComponentID ?? viewModel.ensureComponent(for: selectedKind, visitID: visitID) {
                    viewModel.attachTextNoteToComponent(text: textNoteContent, to: componentID, in: visitID)
                }
            }
        }
        .sheet(isPresented: $isPresentingAdvancedDetails) {
            advancedDetailsSheet
        }
        .confirmationDialog("Set Section Status", isPresented: $isPresentingStatusDialog) {
            ForEach(SectionStatus.allCases, id: \.self) { status in
                Button(status.title) {
                    statusBinding.wrappedValue = status
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: recorder.errorMessage) { _, newValue in
            if let newValue { viewModel.errorMessage = newValue }
        }
        .onDisappear {
            if recorder.isRecording { _ = recorder.stopRecording() }
        }
    }

    // MARK: - Top overlay

    private var topOverlay: some View {
        VStack(spacing: 0) {
            statusBadge
            compactSectionSelector
        }
        .background(
            LinearGradient(
                colors: [.black.opacity(0.55), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Text(selectedKind.surveyTitle)
                .font(.caption.weight(.bold))
            Circle()
                .fill(sectionStatus.indicatorColor)
                .frame(width: 7, height: 7)
            Text(sectionStatus.title)
                .font(.caption)
            if evidenceCount > 0 {
                Label("\(evidenceCount)", systemImage: "camera.fill")
                    .font(.caption)
                    .padding(.leading, 4)
            }
            Spacer()
            Button {
                isPresentingAdvancedDetails = true
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.subheadline)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private var compactSectionSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(sections, id: \.kind.id) { section in
                    Button {
                        selectedKind = section.kind
                    } label: {
                        HStack(spacing: 4) {
                            Text(section.kind.surveyTitle)
                                .font(.caption2.weight(.semibold))
                            if section.isRequired {
                                Circle()
                                    .frame(width: 5, height: 5)
                            }
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .foregroundStyle(selectedKind == section.kind ? .white : .white.opacity(0.75))
                        .background(
                            selectedKind == section.kind
                                ? Color.accentColor
                                : Color.white.opacity(0.15)
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Bottom overlay

    private var bottomOverlay: some View {
        ZStack {
            LinearGradient(
                colors: [.clear, .black.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )
            arcQuickActions
                .padding(.bottom, 8)
        }
        .frame(height: 172)
    }

    // MARK: - Arc quick actions
    // Buttons fan symmetrically upward from the bottom-centre anchor.
    // Angles are distributed around −90° (straight up) so all buttons
    // remain within the container bounds.
    private var arcQuickActions: some View {
        GeometryReader { geometry in
            let arcAngles: [Double] = [-160, -125, -90, -55, -20]
            let labels = [
                ("Photo", "camera.fill"),
                (recorder.isRecording ? "Stop" : "Voice", recorder.isRecording ? "stop.fill" : "waveform"),
                ("Text", "text.bubble.fill"),
                ("Status", "checkmark.seal.fill"),
                (reviewLaterBinding.wrappedValue ? "Reviewed" : "Review", "clock.badge.questionmark")
            ]
            let radius = min(geometry.size.width * 0.38, 108.0)

            ZStack {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, item in
                    let angle = Angle(degrees: arcAngles[index])
                    let x = geometry.size.width / 2 + CGFloat(cos(angle.radians)) * radius
                    let y = geometry.size.height + CGFloat(sin(angle.radians)) * radius

                    Button {
                        handleQuickAction(index)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: item.1)
                                .font(.headline)
                            Text(item.0)
                                .font(.caption2)
                        }
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            recorder.isRecording && index == 1
                                ? Color.red
                                : Color.accentColor
                        )
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                    .position(x: x, y: y)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Advanced details sheet

    private var advancedDetailsSheet: some View {
        NavigationStack {
            List {
                if components.isEmpty {
                    Text("No section components yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(components.enumerated()), id: \.element.id) { index, component in
                    NavigationLink("Component \(index + 1)") {
                        ComponentDetailView(viewModel: viewModel, visitID: visitID, componentID: component.id)
                    }
                }
                Button("Add Another \(selectedKind.surveyTitle)") {
                    viewModel.addComponent(to: visitID, kind: selectedKind, name: "", manufacturer: "", model: "", notes: "")
                }
            }
            .navigationTitle("\(selectedKind.surveyTitle) Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresentingAdvancedDetails = false }
                }
            }
        }
    }

    // MARK: - Actions

    private func handleQuickAction(_ index: Int) {
        switch index {
        case 0:
            activeComponentID = viewModel.ensureComponent(for: selectedKind, visitID: visitID)
            if activeComponentID != nil { isPresentingCamera = true }
        case 1:
            toggleVoiceRecording()
        case 2:
            activeComponentID = viewModel.ensureComponent(for: selectedKind, visitID: visitID)
            if activeComponentID != nil {
                textNoteContent = ""
                isPresentingTextNote = true
            }
        case 3:
            isPresentingStatusDialog = true
        case 4:
            reviewLaterBinding.wrappedValue.toggle()
        default:
            break
        }
    }

    private func toggleVoiceRecording() {
        if recorder.isRecording {
            if let componentID = activeComponentID, let url = recorder.stopRecording() {
                viewModel.attachVoiceNoteToComponent(from: url, to: componentID, in: visitID)
            }
            activeComponentID = nil
            return
        }

        guard let componentID = viewModel.ensureComponent(for: selectedKind, visitID: visitID),
              let url = viewModel.prepareComponentVoiceNoteURL(for: componentID, in: visitID) else {
            return
        }
        activeComponentID = componentID
        recorder.startRecording(to: url)
    }
}

// MARK: - SectionStatus UI helpers

private extension SectionStatus {
    var indicatorColor: Color {
        switch self {
        case .notChecked:    return .gray
        case .present:       return .green
        case .notPresent:    return .orange
        case .unknown:       return .yellow
        case .notAccessible: return .red
        }
    }
}

// MARK: - Text note sheet

private struct SurveySectionTextNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .padding()
                .navigationTitle("Text Note")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onSave()
                            dismiss()
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
    }
}
