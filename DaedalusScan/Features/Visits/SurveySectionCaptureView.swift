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
    @State private var textNoteContent = ""
    @State private var activeComponentID: UUID?
    @State private var isShowingAdvancedDetails = false

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

    private var cockpitContent: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 12) {
                sectionSelector
                sectionContext
                cameraSurface
                advancedSection
                Spacer(minLength: 96)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            arcQuickActions
                .padding(.bottom, 18)
        }
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

    private var sectionSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sections, id: \.kind.id) { section in
                    Button {
                        selectedKind = section.kind
                    } label: {
                        HStack(spacing: 6) {
                            Text(section.kind.surveyTitle)
                                .font(.caption.weight(.semibold))
                            if section.isRequired {
                                Circle()
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .foregroundStyle(selectedKind == section.kind ? .white : .primary)
                        .background(selectedKind == section.kind ? Color.accentColor : Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var sectionContext: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedKind.surveyTitle)
                    .font(.headline)
                Text("Status: \(sectionStatus.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(evidenceCount)")
                    .font(.headline)
                Text("evidence")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var cameraSurface: some View {
        Button {
            activeComponentID = viewModel.ensureComponent(for: selectedKind, visitID: visitID)
            if activeComponentID != nil { isPresentingCamera = true }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.92))
                VStack(spacing: 10) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 42))
                    Text("Camera Preview")
                        .font(.headline)
                    Text("Tap to capture \(selectedKind.surveyTitle.lowercased()) evidence")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 320)
        }
        .buttonStyle(.plain)
    }

    private var advancedSection: some View {
        DisclosureGroup("Advanced Details", isExpanded: $isShowingAdvancedDetails) {
            if components.isEmpty {
                Text("No section components yet.")
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }
            ForEach(Array(components.enumerated()), id: \.element.id) { index, component in
                NavigationLink("Component \(index + 1)") {
                    ComponentDetailView(viewModel: viewModel, visitID: visitID, componentID: component.id)
                }
            }
            Button("Add Another \(selectedKind.surveyTitle)") {
                viewModel.addComponent(to: visitID, kind: selectedKind, name: "", manufacturer: "", model: "", notes: "")
            }
            .padding(.top, 4)
        }
    }

    private var arcQuickActions: some View {
        GeometryReader { geometry in
            let labels = [
                ("Photo", "camera.fill"),
                (recorder.isRecording ? "Stop" : "Voice", recorder.isRecording ? "stop.fill" : "waveform"),
                ("Text", "text.bubble.fill"),
                ("Status", "checkmark.seal.fill"),
                (reviewLaterBinding.wrappedValue ? "Reviewed" : "Review", "clock.badge.questionmark")
            ]

            ZStack {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, item in
                    let angle = Angle(degrees: Double(-80 + (index * 40)))
                    let radius = min(geometry.size.width * 0.42, 118)
                    let x = (geometry.size.width / 2) + CGFloat(cos(angle.radians)) * radius
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
                        .frame(width: 58, height: 58)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .position(x: x, y: y)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 128)
    }

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
