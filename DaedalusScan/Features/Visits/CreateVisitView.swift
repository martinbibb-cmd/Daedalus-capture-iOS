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
    @State private var captureMode: CaptureMode = .create

    let onCreate: (String, String, String, String, String?, Date?, String, HeatingSystemType, CaptureMode) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Property Twin") {
                    TextField("Property reference (required)", text: $reference)
                        .textInputAutocapitalization(.characters)
                    LabeledContent("Twin Layers", value: "System · House · Home")
                    Text("Enter what is known now, then continue directly into capture.")
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

                Section("Twin Context") {
                    Picker("Lifecycle", selection: $captureMode) {
                        ForEach(CaptureMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    Picker("Existing reality", selection: $currentSystemType) {
                        ForEach(HeatingSystemType.allCases, id: \.self) { type in
                            Text(type.title).tag(type)
                        }
                    }
                }
            }
            .navigationTitle("New Property Twin")
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
