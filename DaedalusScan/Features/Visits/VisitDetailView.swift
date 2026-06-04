import DaedalusContracts
import SwiftUI

struct VisitDetailView: View {
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID

    @State private var isPresentingRoomAlert = false
    @State private var isPresentingSummary = false
    @State private var roomName = ""
    @State private var addingComponentKind: SystemComponentKind?

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

                ForEach(SystemComponentKind.canonicalOrder, id: \.id) { kind in
                    let captured = visit.components.filter { $0.kind == kind }
                    let statusBinding = Binding<SectionStatus>(
                        get: { visit.sectionStatuses[kind] ?? .notChecked },
                        set: { viewModel.setSectionStatus($0, for: kind, visitID: visitID) }
                    )
                    Section(kind.title) {
                        Picker("Status", selection: statusBinding) {
                            ForEach(SectionStatus.allCases, id: \.self) { status in
                                Text(status.title).tag(status)
                            }
                        }
                        .pickerStyle(.menu)
                        ForEach(captured) { component in
                            NavigationLink {
                                ComponentDetailView(viewModel: viewModel, visitID: visitID, componentID: component.id)
                            } label: {
                                componentRowLabel(for: component)
                            }
                        }
                        Button("Add \(kind.title)") {
                            addingComponentKind = kind
                        }
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
            }
            .navigationTitle(visit.reference)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Summary") {
                        isPresentingSummary = true
                    }
                }
            }
            .navigationDestination(isPresented: $isPresentingSummary) {
                VisitSummaryView(visit: visit)
            }
            .alert("Add Room", isPresented: $isPresentingRoomAlert) {
                TextField("Room name", text: $roomName)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    viewModel.addRoom(to: visitID, named: roomName)
                }
            } message: {
                Text("Create a room to continue structured capture.")
            }
            .sheet(item: $addingComponentKind) { kind in
                AddComponentView(defaultKind: kind) { kind, name, manufacturer, model, notes in
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

    @ViewBuilder
    private func componentRowLabel(for component: SystemComponent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !component.name.isEmpty {
                Text(component.name)
            } else if !component.manufacturer.isEmpty || !component.model.isEmpty {
                Text([component.manufacturer, component.model]
                    .filter { !$0.isEmpty }
                    .joined(separator: " "))
            } else {
                Text(component.kind.title)
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
