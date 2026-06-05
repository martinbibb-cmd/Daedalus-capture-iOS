import SwiftUI

struct AddComponentView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var kind: SystemComponentKind
    @State private var name = ""
    @State private var manufacturer = ""
    @State private var model = ""
    @State private var notes = ""

    let onAdd: (SystemComponentKind, String, String, String, String) -> Void

    init(defaultKind: SystemComponentKind = .boiler, onAdd: @escaping (SystemComponentKind, String, String, String, String) -> Void) {
        _kind = State(initialValue: defaultKind)
        self.onAdd = onAdd
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Component type", selection: $kind) {
                    ForEach(SystemComponentKind.allCases) { value in
                        Text(value.title).tag(value)
                    }
                }

                TextField("Name", text: $name)
                TextField("Manufacturer", text: $manufacturer)
                TextField("Model", text: $model)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...8)
            }
            .navigationTitle("Add Component")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(kind, name, manufacturer, model, notes)
                        dismiss()
                    }
                }
            }
        }
    }
}
