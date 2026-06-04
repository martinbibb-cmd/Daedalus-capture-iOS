import SwiftUI

struct VisitDetailView: View {
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID

    @State private var isPresentingRoomAlert = false
    @State private var roomName = ""
    @State private var isPresentingAddComponent = false

    var body: some View {
        if let visit = viewModel.visit(id: visitID) {
            List {
                Section("Visit") {
                    LabeledContent("Reference", value: visit.reference)
                    LabeledContent("Twin", value: visit.twinKind.title)
                    LabeledContent("Created") {
                        Text(visit.createdAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }

                Section("Rooms") {
                    ForEach(visit.rooms) { room in
                        NavigationLink(room.name) {
                            RoomDetailView(viewModel: viewModel, visitID: visitID, roomID: room.id)
                        }
                    }

                    Button("Add Room") {
                        roomName = ""
                        isPresentingRoomAlert = true
                    }
                }

                Section("Components") {
                    if visit.components.isEmpty {
                        Text("No components captured yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(visit.components) { component in
                            NavigationLink {
                                ComponentDetailView(viewModel: viewModel, visitID: visitID, componentID: component.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(component.kind.title)
                                        .font(.headline)
                                    if !component.name.isEmpty {
                                        Text(component.name)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    if !component.notes.isEmpty {
                                        Text(component.notes)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                    }

                    Button("Add Component") {
                        isPresentingAddComponent = true
                    }
                }
            }
            .navigationTitle(visit.reference)
            .alert("Add Room", isPresented: $isPresentingRoomAlert) {
                TextField("Room name", text: $roomName)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    viewModel.addRoom(to: visitID, named: roomName)
                }
            } message: {
                Text("Create a room to continue structured capture.")
            }
            .sheet(isPresented: $isPresentingAddComponent) {
                AddComponentView { kind, name, manufacturer, model, notes in
                    viewModel.addComponent(
                        to: visitID,
                        kind: kind,
                        name: name,
                        manufacturer: manufacturer,
                        model: model,
                        notes: notes
                    )
                }
            }
        } else {
            Text("Visit not found")
                .foregroundStyle(.secondary)
        }
    }
}
