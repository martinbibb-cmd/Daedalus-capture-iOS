import SwiftUI

struct VisitSummaryView: View {
    let visit: Visit

    private var components: [SystemComponent] {
        visit.components.filter { $0.captureMode == visit.captureMode }
    }

    private var totalEvidence: Int {
        let areaEvidence = visit.areas.reduce(0) { $0 + $1.evidence.count }
        let componentEvidence = components.reduce(0) { $0 + $1.evidence.count }
        return areaEvidence + componentEvidence
    }

    var body: some View {
        List {
            Section("Capture Overview") {
                LabeledContent("Captured areas", value: "\(visit.areas.count)")
                LabeledContent("Captured components", value: "\(components.count)")
                LabeledContent("Relationships", value: "\(visit.relationships.count)")
                LabeledContent("Evidence items", value: "\(totalEvidence)")
            }

            Section("Capture Ledger") {
                ForEach(SystemComponentCategory.allCases.filter { $0 != .unknown }, id: \.id) { category in
                    let count = components.filter { $0.canonicalCategory == category }.count
                    HStack {
                        Text(category.title)
                        Spacer()
                        Text(count == 0 ? "?" : count == 1 ? "✓" : "\(count) captured")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Observed Completeness") {
                completenessRow("Heat Source", observed: components.contains { $0.canonicalCategory == .heatSource })
                completenessRow("Hot Water", observed: components.contains { $0.canonicalCategory == .hotWater })
                completenessRow("Controls", observed: components.contains { $0.canonicalCategory == .control })
                completenessRow("Emitters", observed: components.contains { $0.canonicalCategory == .emitter })
                completenessRow("Meters", observed: components.contains { $0.canonicalSubtype == .gasMeter })
            } footer: {
                Text("Unknown remains valid and exportable.")
            }
        }
        .navigationTitle("Capture Summary")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func completenessRow(_ label: String, observed: Bool) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(observed ? "✓" : "?")
                .foregroundStyle(.secondary)
        }
    }
}
