import Combine
import Foundation

@MainActor
public final class VisitListViewModel: ObservableObject {
    struct PendingImportConflict {
        let sourceURL: URL
        let conflictCount: Int
        let sampleReference: String
    }

    @Published private(set) var visits: [Visit] = []
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published private(set) var pendingImportConflict: PendingImportConflict?

    private let repository: VisitRepository

    public init(repository: VisitRepository) {
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

    func createVisit(
        reference: String,
        customerName: String = "",
        addressLine: String = "",
        postcode: String = "",
        engineerName: String? = nil,
        appointmentDate: Date? = nil,
        notes: String = "",
        currentSystemType: HeatingSystemType = .unknown,
        proposedSystemType: HeatingSystemType = .unknown,
        captureMode: CaptureMode = .current
    ) -> UUID? {
        let trimmedReference = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReference.isEmpty else {
            errorMessage = "Visit reference is required."
            return nil
        }

        let visit = Visit(
            reference: trimmedReference,
            twinKind: .system,
            customerName: customerName.trimmingCharacters(in: .whitespacesAndNewlines),
            addressLine: addressLine.trimmingCharacters(in: .whitespacesAndNewlines),
            postcode: postcode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            engineerName: normalizedOptionalString(engineerName ?? ""),
            appointmentDate: appointmentDate,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            currentSystemType: currentSystemType,
            proposedSystemType: proposedSystemType,
            captureMode: captureMode
        )
        visits.insert(
            visit,
            at: 0
        )
        persistChanges()
        return visit.id
    }

    func addRoom(to visitID: UUID, named name: String, placement: SpatialPlacement? = nil) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, let visitIndex = indexOfVisit(visitID) else {
            errorMessage = "Room name is required."
            return
        }

        visits[visitIndex].rooms.append(
            Room(
                name: trimmedName,
                spatialPlacement: placement ?? SpatialPlacement(captureState: .approximate, confidence: .low)
            )
        )
        persistChanges()
    }

    func ensureScannedArea(in visitID: UUID) -> UUID? {
        guard let visitIndex = indexOfVisit(visitID) else { return nil }
        let nextIndex = visits[visitIndex].rooms.count + 1
        let room = Room(
            name: "Scanned Area \(nextIndex)",
            spatialPlacement: SpatialPlacement(captureState: .approximate, confidence: .low)
        )
        visits[visitIndex].rooms.append(room)
        persistChanges()
        return room.id
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

    func setRoomReviewStatus(_ status: ReviewStatus?, roomID: UUID, visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID), let roomIndex = indexOfRoom(roomID, in: visitIndex) else {
            return
        }
        visits[visitIndex].rooms[roomIndex].reviewStatus = status
        persistChanges()
    }

    func setRoomReviewNotes(_ notes: String, roomID: UUID, visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID), let roomIndex = indexOfRoom(roomID, in: visitIndex) else {
            return
        }
        visits[visitIndex].rooms[roomIndex].reviewNotes = normalizedOptionalString(notes)
        persistChanges()
    }

    func setRoomNotes(_ notes: String, roomID: UUID, visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID), let roomIndex = indexOfRoom(roomID, in: visitIndex) else {
            return
        }
        visits[visitIndex].rooms[roomIndex].notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        persistChanges()
    }

    func setCaptureMode(_ mode: CaptureMode, for visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID) else { return }
        visits[visitIndex].captureMode = mode
        persistChanges()
    }

    func setCurrentSystemType(_ type: HeatingSystemType, for visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID) else { return }
        visits[visitIndex].currentSystemType = type
        persistChanges()
    }

    func setProposedSystemType(_ type: HeatingSystemType, for visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID) else { return }
        visits[visitIndex].proposedSystemType = type
        persistChanges()
    }

    func setVisitNotes(_ notes: String, for visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID) else { return }
        visits[visitIndex].notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        persistChanges()
    }

    func sectionList(for visitID: UUID) -> [CaptureSection] {
        guard let visit = visit(id: visitID) else { return [] }
        let systemType = visit.captureMode == .current ? visit.currentSystemType : visit.proposedSystemType
        return SystemComponentKind.captureSections(for: systemType)
    }

    func setSurveyResponseReviewStatus(
        _ status: ReviewStatus?,
        questionKey: String,
        roomID: UUID,
        visitID: UUID
    ) {
        guard let visitIndex = indexOfVisit(visitID), let roomIndex = indexOfRoom(roomID, in: visitIndex) else {
            return
        }
        guard var response = visits[visitIndex].rooms[roomIndex].survey[questionKey] else {
            return
        }
        response.reviewStatus = status
        visits[visitIndex].rooms[roomIndex].survey[questionKey] = response
        persistChanges()
    }

    func setSurveyResponseReviewNotes(
        _ notes: String,
        questionKey: String,
        roomID: UUID,
        visitID: UUID
    ) {
        guard let visitIndex = indexOfVisit(visitID), let roomIndex = indexOfRoom(roomID, in: visitIndex) else {
            return
        }
        guard var response = visits[visitIndex].rooms[roomIndex].survey[questionKey] else {
            return
        }
        response.reviewNotes = normalizedOptionalString(notes)
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

    func attachPhoto(data: Data, toComponent componentID: UUID, in visitID: UUID) {
        do {
            let url = try repository.makeEvidenceFileURL(fileExtension: "jpg", visitID: visitID, componentID: componentID)
            try data.write(to: url, options: .atomic)
            appendEvidence(Evidence(kind: .photo, localFileName: url.lastPathComponent), toComponent: componentID, in: visitID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func prepareRoomVoiceNoteURL(for roomID: UUID, in visitID: UUID) -> URL? {
        do {
            return try repository.makeEvidenceFileURL(fileExtension: "m4a", visitID: visitID, roomID: roomID)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func prepareComponentVoiceNoteURL(for componentID: UUID, in visitID: UUID) -> URL? {
        do {
            return try repository.makeEvidenceFileURL(fileExtension: "m4a", visitID: visitID, componentID: componentID)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func attachVoiceNoteToRoom(from url: URL, to roomID: UUID, in visitID: UUID) {
        appendEvidence(Evidence(kind: .voiceNote, localFileName: url.lastPathComponent), to: roomID, in: visitID)
    }

    func attachVoiceNoteToComponent(from url: URL, to componentID: UUID, in visitID: UUID) {
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

    func attachTextNoteToComponent(text: String, to componentID: UUID, in visitID: UUID) {
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

    func setSectionStatus(_ status: SectionStatus, for kind: SystemComponentKind, visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID) else { return }
        if visits[visitIndex].captureMode == .current {
            visits[visitIndex].sectionStatuses[kind] = status
        } else {
            visits[visitIndex].proposedSectionStatuses[kind] = status
        }
        persistChanges()
    }

    func addSpatialObject(
        to visitID: UUID,
        kind: SystemComponentKind,
        areaID: UUID?,
        placement: SpatialPlacement? = nil
    ) -> UUID? {
        guard let visitIndex = indexOfVisit(visitID) else { return nil }
        let captureMode = visits[visitIndex].captureMode
        let component = SystemComponent(
            kind: kind,
            captureMode: captureMode,
            spatialPlacement: placement ?? SpatialPlacement(captureState: .failed, confidence: .unknown)
        )
        visits[visitIndex].components.append(component)
        persistChanges()
        applyAreaReference(
            toComponent: component.id,
            roomID: areaID,
            visitID: visitID,
            preserveExistingPlacement: placement != nil
        )
        return component.id
    }

    func ensureComponent(for kind: SystemComponentKind, visitID: UUID) -> UUID? {
        guard let visitIndex = indexOfVisit(visitID) else { return nil }
        let captureMode = visits[visitIndex].captureMode
        if let existing = visits[visitIndex].components.first(where: { $0.kind == kind && $0.captureMode == captureMode }) {
            return existing.id
        }
        let component = SystemComponent(
            kind: kind,
            captureMode: captureMode,
            spatialPlacement: SpatialPlacement(captureState: .failed, confidence: .unknown)
        )
        visits[visitIndex].components.append(component)
        persistChanges()
        return component.id
    }

    func applyAreaReference(
        toComponent componentID: UUID,
        roomID: UUID?,
        visitID: UUID,
        preserveExistingPlacement: Bool = false
    ) {
        guard let visitIndex = indexOfVisit(visitID),
              let componentIndex = indexOfComponent(componentID, in: visitIndex) else {
            return
        }

        if let roomID,
           let roomIndex = indexOfRoom(roomID, in: visitIndex) {
            let room = visits[visitIndex].rooms[roomIndex]
            if !preserveExistingPlacement {
                visits[visitIndex].components[componentIndex].spatialPlacement = SpatialPlacement(
                    captureState: .areaReferenceOnly,
                    confidence: .low
                )
            }
            visits[visitIndex].components[componentIndex].componentAttributes["location"] = room.name
        } else {
            if !preserveExistingPlacement {
                visits[visitIndex].components[componentIndex].spatialPlacement = SpatialPlacement(
                    captureState: .failed,
                    confidence: .unknown
                )
            }
            visits[visitIndex].components[componentIndex].componentAttributes.removeValue(forKey: "location")
        }
        persistChanges()
    }

    func setSectionReviewLater(_ enabled: Bool, for kind: SystemComponentKind, visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID) else { return }
        let captureMode = visits[visitIndex].captureMode
        var didChange = false
        for index in visits[visitIndex].components.indices where
            visits[visitIndex].components[index].kind == kind &&
            visits[visitIndex].components[index].captureMode == captureMode {
            if enabled {
                if visits[visitIndex].components[index].reviewStatus == nil {
                    visits[visitIndex].components[index].reviewStatus = .needsReview
                    didChange = true
                }
            } else if visits[visitIndex].components[index].reviewStatus == .needsReview {
                visits[visitIndex].components[index].reviewStatus = nil
                didChange = true
            }
        }
        if didChange {
            persistChanges()
        }
    }

    func setComponentReviewStatus(_ status: ReviewStatus?, componentID: UUID, visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID),
              let componentIndex = indexOfComponent(componentID, in: visitIndex) else {
            return
        }
        visits[visitIndex].components[componentIndex].reviewStatus = status
        persistChanges()
    }

    func setComponentReviewNotes(_ notes: String, componentID: UUID, visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID),
              let componentIndex = indexOfComponent(componentID, in: visitIndex) else {
            return
        }
        visits[visitIndex].components[componentIndex].reviewNotes = normalizedOptionalString(notes)
        persistChanges()
    }

    func updateComponentAttribute(
        _ value: String,
        for key: String,
        componentID: UUID,
        visitID: UUID
    ) {
        guard let visitIndex = indexOfVisit(visitID),
              let componentIndex = indexOfComponent(componentID, in: visitIndex) else {
            return
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            visits[visitIndex].components[componentIndex].componentAttributes.removeValue(forKey: key)
        } else {
            visits[visitIndex].components[componentIndex].componentAttributes[key] = trimmed
        }
        persistChanges()
    }

    func deleteVisit(id: UUID) {
        if let visit = visits.first(where: { $0.id == id }) {
            repository.deleteEvidenceFiles(for: visit)
        }
        visits.removeAll { $0.id == id }
        persistChanges()
    }

    func makeExportTempURL() -> URL? {
        do {
            let document = try VisitExportDocument(package: try repository.exportPackage(visits: visits))
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("DaedalusScanExport.daedalusscan")
            try document.data.write(to: url, options: .atomic)
            return url
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func makeExportTempURL(for visitID: UUID) -> URL? {
        guard let visit = visit(id: visitID) else { return nil }
        do {
            let document = try VisitExportDocument(package: try repository.exportPackage(visits: [visit]))
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("DaedalusScanExport_\(visit.reference).daedalusscan")
            try document.data.write(to: url, options: .atomic)
            return url
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func importPackage(from url: URL) {
        do {
            let conflicts = try repository.detectImportConflicts(from: url)
            guard conflicts.isEmpty else {
                pendingImportConflict = PendingImportConflict(
                    sourceURL: url,
                    conflictCount: conflicts.count,
                    sampleReference: conflicts[0].reference
                )
                return
            }

            completeImport(from: url, conflictResolution: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func replaceExistingVisitForPendingImport() {
        resolvePendingImport(with: .replaceExistingVisit)
    }

    func keepBothForPendingImport() {
        resolvePendingImport(with: .keepBoth)
    }

    func cancelPendingImport() {
        pendingImportConflict = nil
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

    func setRoomEvidenceReviewStatus(_ status: ReviewStatus?, evidenceID: UUID, roomID: UUID, visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID), let roomIndex = indexOfRoom(roomID, in: visitIndex) else {
            return
        }
        guard let evidenceIndex = visits[visitIndex].rooms[roomIndex].evidence.firstIndex(where: { $0.id == evidenceID }) else {
            return
        }
        visits[visitIndex].rooms[roomIndex].evidence[evidenceIndex].reviewStatus = status
        persistChanges()
    }

    func setRoomEvidenceReviewNotes(_ notes: String, evidenceID: UUID, roomID: UUID, visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID), let roomIndex = indexOfRoom(roomID, in: visitIndex) else {
            return
        }
        guard let evidenceIndex = visits[visitIndex].rooms[roomIndex].evidence.firstIndex(where: { $0.id == evidenceID }) else {
            return
        }
        visits[visitIndex].rooms[roomIndex].evidence[evidenceIndex].reviewNotes = normalizedOptionalString(notes)
        persistChanges()
    }

    func setComponentEvidenceReviewStatus(_ status: ReviewStatus?, evidenceID: UUID, componentID: UUID, visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID),
              let componentIndex = indexOfComponent(componentID, in: visitIndex) else {
            return
        }
        guard let evidenceIndex = visits[visitIndex].components[componentIndex].evidence.firstIndex(where: { $0.id == evidenceID }) else {
            return
        }
        visits[visitIndex].components[componentIndex].evidence[evidenceIndex].reviewStatus = status
        persistChanges()
    }

    func setComponentEvidenceReviewNotes(_ notes: String, evidenceID: UUID, componentID: UUID, visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID),
              let componentIndex = indexOfComponent(componentID, in: visitIndex) else {
            return
        }
        guard let evidenceIndex = visits[visitIndex].components[componentIndex].evidence.firstIndex(where: { $0.id == evidenceID }) else {
            return
        }
        visits[visitIndex].components[componentIndex].evidence[evidenceIndex].reviewNotes = normalizedOptionalString(notes)
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

    private func normalizedOptionalString(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func resolvePendingImport(with resolution: VisitImportConflictResolution) {
        guard let conflict = pendingImportConflict else { return }
        pendingImportConflict = nil
        completeImport(from: conflict.sourceURL, conflictResolution: resolution)
    }

    private func completeImport(from url: URL, conflictResolution: VisitImportConflictResolution?) {
        do {
            visits = try repository
                .importPackage(from: url, conflictResolution: conflictResolution)
                .sorted { $0.createdAt > $1.createdAt }
            statusMessage = "Import succeeded"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
