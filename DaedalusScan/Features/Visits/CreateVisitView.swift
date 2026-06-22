import SwiftUI

struct CreateVisitView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

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
    @State private var isCreating = false

    let onCreate: (String, String, String, String, String?, Date?, String, HeatingSystemType, CaptureMode) -> Void

    private enum Field: Hashable {
        case reference
        case customerName
        case addressLine
        case postcode
        case engineerName
        case notes
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Property") {
                    TextField("Property reference (required)", text: $reference)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .reference)
                        .submitLabel(.next)
                    LabeledContent("Twin Layers", value: "System · House · Home")
                    Text("Enter what is known now, then continue directly into capture.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Customer & Site") {
                    TextField("Customer name", text: $customerName)
                        .textContentType(.organizationName)
                        .focused($focusedField, equals: .customerName)
                        .submitLabel(.next)
                    TextField("Address", text: $addressLine)
                        .textContentType(.streetAddressLine1)
                        .focused($focusedField, equals: .addressLine)
                        .submitLabel(.next)
                    TextField("Postcode", text: $postcode)
                        .textInputAutocapitalization(.characters)
                        .textContentType(.postalCode)
                        .focused($focusedField, equals: .postcode)
                        .submitLabel(.next)
                }

                Section("Engineer") {
                    TextField("Engineer name (optional)", text: $engineerName)
                        .textContentType(.name)
                        .focused($focusedField, equals: .engineerName)
                        .submitLabel(.next)
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
                        .focused($focusedField, equals: .notes)
                        .submitLabel(.done)
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
            .navigationTitle("New Property")
            .onSubmit {
                advanceFocus()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        createVisit()
                    } label: {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("Start Capture")
                        }
                    }
                    .disabled(reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
        }
    }

    private func createVisit() {
        guard !isCreating else { return }
        focusedField = nil
        isCreating = true

        Task { @MainActor in
            await Task.yield()
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
    }

    private func advanceFocus() {
        switch focusedField {
        case .reference:
            focusedField = .customerName
        case .customerName:
            focusedField = .addressLine
        case .addressLine:
            focusedField = .postcode
        case .postcode:
            focusedField = .engineerName
        case .engineerName:
            focusedField = .notes
        case .notes, nil:
            focusedField = nil
        }
    }
}
