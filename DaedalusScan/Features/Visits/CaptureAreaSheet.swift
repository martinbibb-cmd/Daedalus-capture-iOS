import SwiftUI

struct CaptureAreaSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    let onCapture: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Area name (e.g. Boiler Room)", text: $name)
                } footer: {
                    Text("Placement will be recorded as approximate until spatial anchoring is available.")
                }
            }
            .navigationTitle("Capture Area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onCapture(name.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
