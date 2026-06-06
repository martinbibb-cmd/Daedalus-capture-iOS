import SwiftUI

struct VisitSummaryView: View {
    let visit: Visit

    private var surveySections: [CaptureSection] {
        let systemType = visit.captureMode == .current ? visit.currentSystemType : visit.proposedSystemType
        return SystemComponentKind.captureSections(for: systemType)
    }

    private var totalEvidence: Int {
        let roomEvidence = visit.rooms.reduce(0) { $0 + $1.evidence.count }
        let componentEvidence = visit.components.reduce(0) { $0 + $1.evidence.count }
        return roomEvidence + componentEvidence
    }

    private var totalSurveyResponses: Int {
        visit.rooms.reduce(0) { $0 + $1.survey.count }
    }

    private var reviewStatusCounts: [ReviewStatus: Int] {
        var counts: [ReviewStatus: Int] = [:]
        for room in visit.rooms {
            if let status = room.reviewStatus {
                counts[status, default: 0] += 1
            }
        }
        for component in visit.components {
            if let status = component.reviewStatus {
                counts[status, default: 0] += 1
            }
        }
        return counts
    }

    private var completedSectionCount: Int {
        surveySections.filter { $0.isRequired && isSectionComplete($0.kind) }.count
    }

    private var totalSections: Int { surveySections.filter(\.isRequired).count }

    private var isReadyToExport: Bool {
        totalSections == 0 || completedSectionCount == totalSections
    }

    var body: some View {
        List {
            captureOverviewSection
            readyToExportSection
            canonicalSectionsSection
        }
        .navigationTitle("Capture Summary")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var captureOverviewSection: some View {
        Section("Capture Overview") {
            LabeledContent("Rooms", value: "\(visit.rooms.count)")
            LabeledContent("System components", value: "\(visit.components.count)")
            LabeledContent("Evidence items", value: "\(totalEvidence)")
            LabeledContent("Survey responses", value: "\(totalSurveyResponses)")
            if totalSections == 0 {
                LabeledContent("Sections", value: "Guidance only")
            } else {
                LabeledContent("Sections complete", value: "\(completedSectionCount) / \(totalSections)")
            }
            if !reviewStatusCounts.isEmpty {
                reviewStatusRows
            }
        }
    }

    @ViewBuilder
    private var reviewStatusRows: some View {
        ForEach(ReviewStatus.allCases, id: \.self) { status in
            if let count = reviewStatusCounts[status] {
                LabeledContent(status.title, value: "\(count)")
            }
        }
    }

    private var readyToExportSection: some View {
        Section {
            HStack {
                Image(systemName: isReadyToExport ? "checkmark.circle" : "circle.dashed")
                    .foregroundStyle(isReadyToExport ? Color.green : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ready to Export")
                        .font(.body)
                    Text(
                        totalSections == 0
                            ? "Unknown system type uses guidance-only sections."
                            : isReadyToExport
                            ? "All survey sections have status and/or evidence."
                            : "\(totalSections - completedSectionCount) section\(totalSections - completedSectionCount == 1 ? "" : "s") still need capture."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("Export is available regardless of capture state.")
                .font(.caption)
        }
    }

    private var canonicalSectionsSection: some View {
        Section("Sections") {
            ForEach(surveySections, id: \.kind.id) { section in
                sectionRow(for: section)
            }
        }
    }

    // MARK: - Row builders

    @ViewBuilder
    private func sectionRow(for section: CaptureSection) -> some View {
        let kind = section.kind
        let components = visit.components.filter { $0.kind == kind && $0.captureMode == visit.captureMode }
        let sectionStatus = visit.captureMode == .current
            ? (visit.sectionStatuses[kind] ?? .notChecked)
            : (visit.proposedSectionStatuses[kind] ?? .notChecked)
        let evidenceCount = components.reduce(0) { $0 + $1.evidence.count }
        let needsReviewCount = components.filter { $0.reviewStatus == .needsReview }.count

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(kind.surveyTitle)
                    .font(.headline)
                Spacer()
                sectionStatusBadge(kind: kind, sectionStatus: sectionStatus)
            }
            if !section.isRequired {
                Text("Guidance required, not mandatory")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            HStack(spacing: 16) {
                captureChip(systemImage: "square.stack", value: components.count, label: "components")
                captureChip(systemImage: "paperclip", value: evidenceCount, label: "evidence")
                if needsReviewCount > 0 {
                    captureChip(systemImage: "eye", value: needsReviewCount, label: "needs review")
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func sectionStatusBadge(kind: SystemComponentKind, sectionStatus: SectionStatus) -> some View {
        Text(isSectionComplete(kind) ? "Complete" : sectionStatus.title)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(sectionStatusColor(kind: kind, status: sectionStatus).opacity(0.15))
            .foregroundStyle(sectionStatusColor(kind: kind, status: sectionStatus))
            .clipShape(Capsule())
    }

    private func sectionStatusColor(kind: SystemComponentKind, status: SectionStatus) -> Color {
        if isSectionComplete(kind) {
            return .green
        }
        switch status {
        case .notChecked: return .secondary
        case .present: return .green
        case .notPresent: return .blue
        case .unknown: return .orange
        case .notAccessible: return .red
        }
    }

    @ViewBuilder
    private func captureChip(systemImage: String, value: Int, label: String) -> some View {
        Label("\(value) \(label)", systemImage: systemImage)
    }

    private func isSectionComplete(_ kind: SystemComponentKind) -> Bool {
        let status = visit.captureMode == .current
            ? (visit.sectionStatuses[kind] ?? .notChecked)
            : (visit.proposedSectionStatuses[kind] ?? .notChecked)
        let hasStatus = status != .notChecked
        let hasEvidence = visit.components
            .filter { $0.kind == kind && $0.captureMode == visit.captureMode }
            .contains { !$0.evidence.isEmpty }
        return hasStatus || hasEvidence
    }
}
