import Combine
import DaedalusContracts
import Foundation

@MainActor
final class VisitListViewModel: ObservableObject {
    @Published private(set) var visits: [Visit] = []
    @Published var errorMessage: String?

    private let repository: VisitRepository

    init(repository: VisitRepository) {
        self.repository = repository
        loadVisits()
    }

    func loadVisits() {
        do {
            visits = try repository.loadVisits().sorted { $0.createdAt > $1.createdAt }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createVisit(reference: String, twinKind: TwinKind) {
        let trimmedReference = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReference.isEmpty else {
            errorMessage = "Visit reference is required."
            return
        }

        visits.insert(
            Visit(reference: trimmedReference, twinKind: twinKind, rooms: [Room(name: "Room 1")], components: []),
            at: 0
        )
        persistChanges()
    }

    func addRoom(to visitID: UUID, named name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, let visitIndex = indexOfVisit(visitID) else {
            errorMessage = "Room name is required."
            return
        }

        visits[visitIndex].rooms.append(Room(name: trimmedName))
        persistChanges()
    }

    func visit(id: UUID) -> Visit? {
        visits.first { $0.id == id }
    }

    func room(visitID: UUID, roomID: UUID) -> Room? {
        visit(id: visitID)?.rooms.first { $0.id == roomID }
    }

    func component(visitID: UUID, componentID: UUID) -> SystemComponent? {
        visit(id: visitID)?.components.first { $0.id == componentID }
    }

    func response(for questionKey: String, visitID: UUID, roomID: UUID) -> SurveyResponse {
        room(visitID: visitID, roomID: roomID)?.survey[questionKey] ?? SurveyResponse()
    }

    func updateResponse(_ response: SurveyResponse, for questionKey: String, visitID: UUID, roomID: UUID) {
        guard let visitIndex = indexOfVisit(visitID), let roomIndex = indexOfRoom(roomID, in: visitIndex) else {
            return
        }

        visits[visitIndex].rooms[roomIndex].survey[questionKey] = response
        persistChanges()
    }

    func addComponent(
        to visitID: UUID,
        kind: SystemComponentKind,
        name: String,
        manufacturer: String,
        model: String,
        notes: String
    ) {
        guard let visitIndex = indexOfVisit(visitID) else {
            return
        }

        visits[visitIndex].components.append(
            SystemComponent(
                kind: kind,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                manufacturer: manufacturer.trimmingCharacters(in: .whitespacesAndNewlines),
                model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
        persistChanges()
    }

    func attachPhoto(data: Data, to roomID: UUID, in visitID: UUID) {
        do {
            let url = try repository.makeEvidenceFileURL(fileExtension: "jpg", visitID: visitID, roomID: roomID)
            try data.write(to: url, options: .atomic)
            appendEvidence(Evidence(kind: .photo, localFileName: url.lastPathComponent), to: roomID, in: visitID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func attachPhoto(data: Data, to componentID: UUID, in visitID: UUID) {
        do {
            let url = try repository.makeEvidenceFileURL(fileExtension: "jpg", visitID: visitID, componentID: componentID)
            try data.write(to: url, options: .atomic)
            appendEvidence(Evidence(kind: .photo, localFileName: url.lastPathComponent), toComponent: componentID, in: visitID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func prepareVoiceNoteURL(for roomID: UUID, in visitID: UUID) -> URL? {
        do {
            return try repository.makeEvidenceFileURL(fileExtension: "m4a", visitID: visitID, roomID: roomID)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func prepareVoiceNoteURL(for componentID: UUID, in visitID: UUID) -> URL? {
        do {
            return try repository.makeEvidenceFileURL(fileExtension: "m4a", visitID: visitID, componentID: componentID)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func attachVoiceNote(from url: URL, to roomID: UUID, in visitID: UUID) {
        appendEvidence(Evidence(kind: .voiceNote, localFileName: url.lastPathComponent), to: roomID, in: visitID)
    }

    func attachVoiceNote(from url: URL, to componentID: UUID, in visitID: UUID) {
        appendEvidence(Evidence(kind: .voiceNote, localFileName: url.lastPathComponent), toComponent: componentID, in: visitID)
    }

    func attachTextNote(text: String, to roomID: UUID, in visitID: UUID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let url = try repository.makeEvidenceFileURL(fileExtension: "txt", visitID: visitID, roomID: roomID)
            try Data(trimmed.utf8).write(to: url, options: .atomic)
            appendEvidence(Evidence(kind: .textNote, localFileName: url.lastPathComponent), to: roomID, in: visitID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func attachTextNote(text: String, to componentID: UUID, in visitID: UUID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let url = try repository.makeEvidenceFileURL(fileExtension: "txt", visitID: visitID, componentID: componentID)
            try Data(trimmed.utf8).write(to: url, options: .atomic)
            appendEvidence(Evidence(kind: .textNote, localFileName: url.lastPathComponent), toComponent: componentID, in: visitID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteVisit(id: UUID) {
        if let visit = visits.first(where: { $0.id == id }) {
            repository.deleteEvidenceFiles(for: visit)
        }
        visits.removeAll { $0.id == id }
        persistChanges()
    }

    func makeExportDocument() -> VisitExportDocument? {
        do {
            return try VisitExportDocument(package: repository.exportPackage(visits: visits))
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func importPackage(from url: URL) {
        do {
            visits = try repository.importPackage(from: url).sorted { $0.createdAt > $1.createdAt }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func appendEvidence(_ evidence: Evidence, to roomID: UUID, in visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID), let roomIndex = indexOfRoom(roomID, in: visitIndex) else {
            return
        }

        visits[visitIndex].rooms[roomIndex].evidence.insert(evidence, at: 0)
        persistChanges()
    }

    private func appendEvidence(_ evidence: Evidence, toComponent componentID: UUID, in visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID),
              let componentIndex = indexOfComponent(componentID, in: visitIndex) else {
            return
        }

        visits[visitIndex].components[componentIndex].evidence.insert(evidence, at: 0)
        persistChanges()
    }

    private func indexOfVisit(_ visitID: UUID) -> Int? {
        visits.firstIndex { $0.id == visitID }
    }

    private func indexOfRoom(_ roomID: UUID, in visitIndex: Int) -> Int? {
        visits[visitIndex].rooms.firstIndex { $0.id == roomID }
    }

    private func indexOfComponent(_ componentID: UUID, in visitIndex: Int) -> Int? {
        visits[visitIndex].components.firstIndex { $0.id == componentID }
    }

    private func persistChanges() {
        do {
            try repository.save(visits: visits)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
