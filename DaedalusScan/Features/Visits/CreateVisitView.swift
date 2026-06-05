import SwiftUI

struct CreateVisitView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var reference = ""
    @State private var twinKind: TwinKind = .home
    @State private var customerName = ""
    @State private var addressLine = ""
    @State private var postcode = ""
    @State private var engineerName = ""
    @State private var hasAppointmentDate = false
    @State private var appointmentDate = Date()
    @State private var notes = ""

    let onCreate: (String, TwinKind, String, String, String, String?, Date?, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Visit Identity") {
                    TextField("Visit reference (required)", text: $reference)
                        .textInputAutocapitalization(.characters)

                    Picker("Twin", selection: $twinKind) {
                        ForEach(TwinKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
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
                            twinKind,
                            customerName,
                            addressLine,
                            postcode,
                            engineerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : engineerName,
                            hasAppointmentDate ? appointmentDate : nil,
                            notes
                        )
                        dismiss()
                    }
                    .disabled(reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
