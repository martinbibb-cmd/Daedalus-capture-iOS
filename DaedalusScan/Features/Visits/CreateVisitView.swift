import SwiftUI

struct CreateVisitView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var reference = ""
    @State private var customerName = ""
    @State private var addressLine = ""
    @State private var postcode = ""
    @State private var engineerName = ""
    @State private var hasAppointmentDate = false
    @State private var appointmentDate = Date()
    @State private var notes = ""
    @State private var currentSystemType: HeatingSystemType = .unknown
    @State private var proposedSystemType: HeatingSystemType = .unknown
    @State private var captureMode: CaptureMode = .current

    let onCreate: (String, String, String, String, String?, Date?, String, HeatingSystemType, HeatingSystemType, CaptureMode) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Minimal Visit Metadata") {
                    TextField("Visit reference (required)", text: $reference)
                        .textInputAutocapitalization(.characters)
                    LabeledContent("Twin Layers", value: "System · House · Home")
                    Text("Enter what you have now, then continue directly into live capture.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Customer & Site") {
                    TextField("Customer name", text: $customerName)
                        .textContentType(.organizationName)
                    TextField("Address", text: $addressLine)
                        .textContentType(.streetAddressLine1)
                    TextField("Postcode", text: $postcode)
                        .textInputAutocapitalization(.characters)
                        .textContentType(.postalCode)
                }

                Section("Engineer") {
                    TextField("Engineer name (optional)", text: $engineerName)
                        .textContentType(.name)
                }

                Section("Appointment") {
                    Toggle("Set appointment date", isOn: $hasAppointmentDate)
                    if hasAppointmentDate {
                        DatePicker(
                            "Date",
                            selection: $appointmentDate,
                            displayedComponents: [.date]
                        )
                    }
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("System Context") {
                    Picker("Capture mode", selection: $captureMode) {
                        ForEach(CaptureMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    Picker("Current system", selection: $currentSystemType) {
                        ForEach(HeatingSystemType.allCases, id: \.self) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    Picker("Proposed system", selection: $proposedSystemType) {
                        ForEach(HeatingSystemType.allCases, id: \.self) { type in
                            Text(type.title).tag(type)
                        }
                    }
                }
            }
            .navigationTitle("Create Visit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(
                            reference,
                            customerName,
                            addressLine,
                            postcode,
                            engineerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : engineerName,
                            hasAppointmentDate ? appointmentDate : nil,
                            notes,
                            currentSystemType,
                            proposedSystemType,
                            captureMode
                        )
                        dismiss()
                    }
                    .disabled(reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
