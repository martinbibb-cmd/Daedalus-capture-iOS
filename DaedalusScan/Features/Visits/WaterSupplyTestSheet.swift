import SwiftUI

struct WaterSupplyTestSheet: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID

    @State private var method: WaterSupplyMethod = .flowCup
    @State private var location: WaterSupplyLocation = .kitchenColdTap
    @State private var intent: WaterSupplyIntent = .usableHouseholdCapacity
    @State private var instrument = ""
    @State private var flowRate = ""
    @State private var staticPressure = ""
    @State private var dynamicPressure = ""
    @State private var residualPressure = ""
    @State private var flowAtZeroBar = ""
    @State private var flowAtOneBar = ""
    @State private var qualitativeObservation = ""
    @State private var absenceReason: WaterAbsenceReason = .equipmentUnavailable
    @State private var mainsStopTapFullyOpen: WaterBoundaryState = .unknown
    @State private var visiblePrvFitted: WaterBoundaryState = .unknown
    @State private var softenerOrFilterPresent: WaterBoundaryState = .unknown
    @State private var otherOutletsOpenDuringTest: WaterBoundaryState = .unknown
    @State private var restrictorOrAeratorSuspected: WaterBoundaryState = .unknown
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Observation") {
                    Picker("Method", selection: $method) {
                        ForEach(WaterSupplyMethod.allCases) { method in
                            Text(method.title).tag(method)
                        }
                    }
                    Text(method.qualityHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Location", selection: $location) {
                        ForEach(WaterSupplyLocation.allCases) { location in
                            Text(location.title).tag(location)
                        }
                    }
                    Picker("Intent", selection: $intent) {
                        ForEach(WaterSupplyIntent.allCases) { intent in
                            Text(intent.title).tag(intent)
                        }
                    }
                    TextField("Instrument or kit", text: $instrument)
                }

                Section("Values") {
                    if method == .notTested {
                        Picker("Reason", selection: $absenceReason) {
                            ForEach(WaterAbsenceReason.allCases) { reason in
                                Text(reason.title).tag(reason)
                            }
                        }
                    } else if method == .customerReported {
                        TextField("Customer report", text: $qualitativeObservation, axis: .vertical)
                    } else {
                        if method == .pressureFlowTestKit || method == .digitalPressureFlowLogger {
                            TextField("Static pressure, bar", text: $staticPressure)
                                .keyboardType(.decimalPad)
                            TextField("Dynamic pressure, bar", text: $dynamicPressure)
                                .keyboardType(.decimalPad)
                            TextField("Flow at 0 bar, l/min", text: $flowAtZeroBar)
                                .keyboardType(.decimalPad)
                            TextField("Flow at 1 bar, l/min", text: $flowAtOneBar)
                                .keyboardType(.decimalPad)
                        }
                        if method == .flowCup || method == .digitalPressureFlowLogger {
                            TextField("Flow rate, l/min", text: $flowRate)
                                .keyboardType(.decimalPad)
                        }
                        if method == .pressureGauge || method == .digitalPressureFlowLogger {
                            TextField("Residual pressure, bar", text: $residualPressure)
                                .keyboardType(.decimalPad)
                        }
                    }
                }

                Section("Boundary Conditions") {
                    boundaryPicker("Mains stop tap open", selection: $mainsStopTapFullyOpen)
                    boundaryPicker("PRV visible", selection: $visiblePrvFitted)
                    boundaryPicker("Softener/filter present", selection: $softenerOrFilterPresent)
                    boundaryPicker("Other outlets open", selection: $otherOutletsOpenDuringTest)
                    boundaryPicker("Restrictor/aerator suspected", selection: $restrictorOrAeratorSuspected)
                }

                Section("Evidence") {
                    Text("Attach photos, notes, or device logs with Evidence. Water observations can reference that evidence at export time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Notes", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("Water Test")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func boundaryPicker(_ label: String, selection: Binding<WaterBoundaryState>) -> some View {
        Picker(label, selection: selection) {
            ForEach(WaterBoundaryState.allCases) { state in
                Text(state.title).tag(state)
            }
        }
    }

    private func save() {
        let now = Date()
        let observedBy = viewModel.visit(id: visitID)?.engineerName.nilIfEmpty ?? "Daedalus Scan"
        let observation = WaterSupplyObservation(
            observedAt: now,
            observedBy: observedBy,
            method: method,
            location: location,
            intent: method == .notTested ? .notTested : intent,
            instrument: instrument.nilIfEmpty,
            values: measurementValues,
            boundaryConditions: WaterBoundaryConditions(
                mainsStopTapFullyOpen: mainsStopTapFullyOpen,
                visiblePrvFitted: visiblePrvFitted,
                softenerOrFilterPresent: softenerOrFilterPresent,
                otherOutletsOpenDuringTest: otherOutletsOpenDuringTest,
                restrictorOrAeratorSuspected: restrictorOrAeratorSuspected
            ),
            suspectedLimitations: suspectedLimitations,
            absenceReason: method == .notTested ? absenceReason : nil,
            confidence: confidence,
            evidenceIDs: [],
            provenance: TwinProvenance(source: "water-supply-test", observedAt: now, observedBy: observedBy),
            notes: notes.nilIfEmpty
        )
        viewModel.addWaterSupplyObservation(to: visitID, observation: observation)
        dismiss()
    }

    private var measurementValues: [WaterMeasurementValue] {
        var values: [WaterMeasurementValue] = []
        values.appendNumber(.staticPressure, raw: staticPressure, unit: "bar", confidence: confidence)
        values.appendNumber(.dynamicPressure, raw: dynamicPressure, unit: "bar", confidence: confidence)
        values.appendNumber(.residualPressure, raw: residualPressure, unit: "bar", confidence: confidence)
        values.appendNumber(.flowRate, raw: flowRate, unit: "l/min", confidence: confidence)
        values.appendNumber(.flowAtPressure, raw: flowAtZeroBar, unit: "l/min", condition: "0 bar residual pressure", confidence: confidence)
        values.appendNumber(.flowAtPressure, raw: flowAtOneBar, unit: "l/min", condition: "1 bar residual pressure", confidence: confidence)
        if method == .customerReported, let report = qualitativeObservation.nilIfEmpty {
            values.append(WaterMeasurementValue(name: .qualitativeObservation, value: report, confidence: .unknown))
        }
        return values
    }

    private var confidence: Confidence {
        switch method {
        case .digitalPressureFlowLogger, .pressureFlowTestKit, .pressureGauge:
            return .observed
        case .flowCup, .other:
            return .approximate
        case .customerReported, .notTested, .unknown:
            return .unknown
        }
    }

    private var suspectedLimitations: [WaterSuspectedLimitation] {
        switch method {
        case .customerReported:
            return [.customerReportOnly]
        case .flowCup:
            return restrictorOrAeratorSuspected == .true ? [.restrictedOutlet, .aerator] : []
        case .notTested:
            return absenceReason == .noSuitableOutlet ? [.noSuitableOutlet] : []
        default:
            return restrictorOrAeratorSuspected == .true ? [.restrictedOutlet] : []
        }
    }
}

private extension Array where Element == WaterMeasurementValue {
    mutating func appendNumber(
        _ name: WaterMeasurementValueName,
        raw: String,
        unit: String,
        condition: String? = nil,
        confidence: Confidence
    ) {
        guard let value = raw.nilIfEmpty else { return }
        append(WaterMeasurementValue(name: name, value: value, unit: unit, condition: condition, confidence: confidence))
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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

private extension WaterSupplyLocation {
    var title: String {
        rawValue.splitCamelCase
    }
}

private extension WaterSupplyIntent {
    var title: String {
        rawValue.splitCamelCase
    }
}

private extension WaterBoundaryState {
    var title: String {
        rawValue.capitalized
    }
}

private extension WaterAbsenceReason {
    var title: String {
        rawValue.splitCamelCase
    }
}

private extension String {
    var splitCamelCase: String {
        replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
            .capitalized
    }
}
