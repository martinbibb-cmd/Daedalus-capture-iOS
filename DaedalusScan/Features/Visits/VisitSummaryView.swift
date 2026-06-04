import DaedalusContracts
import SwiftUI

struct VisitSummaryView: View {
    let visit: Visit

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

    private var checkedSectionCount: Int {
        SystemComponentKind.canonicalOrder.filter { kind in
            (visit.sectionStatuses[kind] ?? .notChecked) != .notChecked
        }.count
    }

    private var totalSections: Int { SystemComponentKind.canonicalOrder.count }

    private var isReadyToExport: Bool {
        checkedSectionCount == totalSections
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
            LabeledContent("Sections checked", value: "\(checkedSectionCount) / \(totalSections)")
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
                        isReadyToExport
                            ? "All sections have a recorded status."
                            : "\(totalSections - checkedSectionCount) section\(totalSections - checkedSectionCount == 1 ? "" : "s") not yet checked."
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
            ForEach(SystemComponentKind.canonicalOrder, id: \.id) { kind in
                sectionRow(for: kind)
            }
        }
    }

    // MARK: - Row builders

    @ViewBuilder
    private func sectionRow(for kind: SystemComponentKind) -> some View {
        let components = visit.components.filter { $0.kind == kind }
        let sectionStatus = visit.sectionStatuses[kind] ?? .notChecked
        let evidenceCount = components.reduce(0) { $0 + $1.evidence.count }
        let needsReviewCount = components.filter { $0.reviewStatus == .needsReview }.count

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(kind.title)
                    .font(.headline)
                Spacer()
                sectionStatusBadge(sectionStatus)
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
    private func sectionStatusBadge(_ status: SectionStatus) -> some View {
        Text(status.title)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(sectionStatusColor(status).opacity(0.15))
            .foregroundStyle(sectionStatusColor(status))
            .clipShape(Capsule())
    }

    private func sectionStatusColor(_ status: SectionStatus) -> Color {
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
}
