import SwiftUI

struct CaptureObjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kind: SystemComponentKind = .boiler
    @State private var selectedAreaID: UUID?
    let areas: [Room]
    let onCapture: (SystemComponentKind, UUID?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Object Type") {
                    Picker("Type", selection: $kind) {
                        ForEach(SystemComponentKind.allCases) { k in
                            Text(k.title).tag(k)
                        }
                    }
                }

                Section("Location") {
                    if areas.isEmpty {
                        Text("No areas captured yet — object will be placed as evidence-only.")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    } else {
                        Picker("Area", selection: $selectedAreaID) {
                            Text("None (evidence-only)").tag(Optional<UUID>.none)
                            ForEach(areas) { area in
                                Text(area.name).tag(Optional(area.id))
                            }
                        }
                    }
                } footer: {
                    Text(
                        selectedAreaID != nil
                            ? "Object will be placed as area-attached."
                            : "Object will be placed as evidence-only until an area is assigned."
                    )
                }
            }
            .navigationTitle("Capture Object")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onCapture(kind, selectedAreaID)
                        dismiss()
                    }
                }
            }
        }
    }
}
