import SwiftUI

struct AttachEvidenceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID

    private var visit: Visit? { viewModel.visit(id: visitID) }

    var body: some View {
        NavigationStack {
            Group {
                if let visit {
                    let components = visit.components.filter { $0.captureMode == visit.captureMode }
                    if visit.rooms.isEmpty && components.isEmpty {
                        ContentUnavailableView(
                            "No Entities Captured",
                            systemImage: "cube.transparent",
                            description: Text("Add a spatial area or object first, then attach evidence to it.")
                        )
                    } else {
                        List {
                            if !visit.rooms.isEmpty {
                                Section("Areas") {
                                    ForEach(visit.rooms) { room in
                                        NavigationLink(room.name) {
                                            RoomDetailView(
                                                viewModel: viewModel,
                                                visitID: visitID,
                                                roomID: room.id
                                            )
                                        }
                                    }
                                }
                            }
                            if !components.isEmpty {
                                Section("Objects") {
                                    ForEach(components) { component in
                                        NavigationLink {
                                            ComponentDetailView(
                                                viewModel: viewModel,
                                                visitID: visitID,
                                                componentID: component.id
                                            )
                                        } label: {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(component.kind.title)
                                                Text(areaLabel(for: component, in: visit))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("Property not found", systemImage: "exclamationmark.triangle")
                }
            }
            .navigationTitle("Attach Evidence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func areaLabel(for component: SystemComponent, in visit: Visit) -> String {
        if let location = component.componentAttributes["location"], !location.isEmpty {
            return location
        }
        return component.spatialPlacement.captureState.title
    }
}
