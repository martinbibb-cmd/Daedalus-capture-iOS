import SwiftUI

struct ServicePointSheet: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID
    let visit: Visit

    @State private var servicePointType: ServicePointType = .bathTap
    @State private var selectedAreaID = ""
    @State private var supplyType: SupplyType = .unknown
    @State private var intendedPressureType: IntendedPressureType = .unknown
    @State private var selectedAssetIDs = Set<String>()
    @State private var selectedIssues = Set<ObservedIssue>()
    @State private var selectedEvidenceIDs = Set<String>()
    @State private var notes = ""

    private var components: [SystemComponent] {
        visit.components.filter { $0.captureMode == visit.captureMode }
    }

    private var evidenceItems: [(id: String, title: String)] {
        let roomEvidence = visit.rooms.flatMap { room in
            room.evidence.map { (id: $0.id.uuidString, title: "\(room.name): \($0.kind.rawValue)") }
        }
        let componentEvidence = components.flatMap { component in
            component.evidence.map { (id: $0.id.uuidString, title: "\(component.name.nilIfEmpty ?? component.canonicalSubtype.title): \($0.kind.rawValue)") }
        }
        return roomEvidence + componentEvidence
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Service Point") {
                    Picker("Outlet/fitting", selection: $servicePointType) {
                        ForEach(ServicePointType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    Picker("Area", selection: $selectedAreaID) {
                        ForEach(visit.areas) { area in
                            Text(area.name).tag(area.id.uuidString)
                        }
                    }
                    Picker("Supply", selection: $supplyType) {
                        ForEach(SupplyType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    Picker("Intended pressure", selection: $intendedPressureType) {
                        ForEach(IntendedPressureType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                }

                Section("Observed Issues") {
                    ForEach(ObservedIssue.allCases) { issue in
                        Toggle(issue.title, isOn: issueBinding(issue))
                    }
                }

                Section("Served By") {
                    if components.isEmpty {
                        Text("No captured assets.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(components) { component in
                            Toggle(component.name.nilIfEmpty ?? component.canonicalSubtype.title, isOn: assetBinding(component.id.uuidString))
                        }
                    }
                }

                Section("Evidence") {
                    if evidenceItems.isEmpty {
                        Text("Use Evidence to add photos or notes, then select them here.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(evidenceItems, id: \.id) { evidence in
                            Toggle(evidence.title, isOn: evidenceBinding(evidence.id))
                        }
                    }
                    TextField("Notes", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("Service Point")
            .onAppear {
                if selectedAreaID.isEmpty {
                    selectedAreaID = visit.areas.first?.id.uuidString ?? ""
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(selectedAreaID.isEmpty)
                }
            }
        }
    }

    private func issueBinding(_ issue: ObservedIssue) -> Binding<Bool> {
        Binding(
            get: { selectedIssues.contains(issue) },
            set: { isSelected in
                if isSelected {
                    selectedIssues.insert(issue)
                } else {
                    selectedIssues.remove(issue)
                }
            }
        )
    }

    private func assetBinding(_ assetID: String) -> Binding<Bool> {
        Binding(
            get: { selectedAssetIDs.contains(assetID) },
            set: { isSelected in
                if isSelected {
                    selectedAssetIDs.insert(assetID)
                } else {
                    selectedAssetIDs.remove(assetID)
                }
            }
        )
    }

    private func evidenceBinding(_ evidenceID: String) -> Binding<Bool> {
        Binding(
            get: { selectedEvidenceIDs.contains(evidenceID) },
            set: { isSelected in
                if isSelected {
                    selectedEvidenceIDs.insert(evidenceID)
                } else {
                    selectedEvidenceIDs.remove(evidenceID)
                }
            }
        )
    }

    private func save() {
        let now = Date()
        let observedBy = viewModel.visit(id: visitID)?.engineerName.nilIfEmpty ?? "Daedalus Scan"
        let observation = ServicePointObservation(
            areaID: selectedAreaID,
            servicePointType: servicePointType,
            supplyType: supplyType,
            intendedPressureType: intendedPressureType,
            servedByAssetIDs: Array(selectedAssetIDs).sorted(),
            observedIssues: Array(selectedIssues).sorted { $0.rawValue < $1.rawValue },
            evidenceIDs: Array(selectedEvidenceIDs).sorted(),
            confidence: selectedIssues.isEmpty && supplyType == .unknown && intendedPressureType == .unknown ? .unknown : .approximate,
            provenance: TwinProvenance(source: "service-point-capture", observedAt: now, observedBy: observedBy),
            notes: notes.nilIfEmpty
        )
        viewModel.addServicePointObservation(to: visitID, observation: observation)
        dismiss()
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var splitCamelCase: String {
        replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
            .capitalized
    }
}

private extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        switch self {
        case .some(let value):
            return value.nilIfEmpty
        case .none:
            return nil
        }
    }
}

private extension ServicePointType {
    var title: String { rawValue.splitCamelCase }
}

private extension SupplyType {
    var title: String { rawValue.splitCamelCase }
}

private extension IntendedPressureType {
    var title: String { rawValue.splitCamelCase }
}

private extension ObservedIssue {
    var title: String { rawValue.splitCamelCase }
}
