import Foundation

enum VisitPackageImportError: LocalizedError {
    case invalidPackage
    case unsupportedSchemaVersion(Int)
    case conflictResolutionRequired

    var errorDescription: String? {
        switch self {
        case .invalidPackage:
            return "The selected package is invalid."
        case let .unsupportedSchemaVersion(version):
            return "This package was created with an unsupported schema version (\(version))."
        case .conflictResolutionRequired:
            return "This package conflicts with existing Properties. Choose how to continue import."
        }
    }
}

enum VisitPackageExportError: LocalizedError {
    case validationFailed([PackageValidationIssue])

    var errorDescription: String? {
        switch self {
        case let .validationFailed(issues):
            let details = issues.prefix(5).map { issue in
                "\(issue.path): \(issue.message)"
            }
            let suffix = issues.count > details.count ? "\n…\(issues.count - details.count) more issue(s)" : ""
            return "Export blocked by contract validation.\n" + details.joined(separator: "\n") + suffix
        }
    }
}

enum VisitImportConflictResolution {
    case replaceExistingVisit
    case keepBoth
}

struct VisitImportConflict {
    let visitID: UUID
    let reference: String
}

@MainActor
public final class VisitRepository {
    private static let supportedSchemaVersion = VisitPackageMetadata.currentSchemaVersion

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let storageDirectoryOverride: URL?

    public init(fileManager: FileManager = .default, storageDirectory: URL? = nil) {
        self.fileManager = fileManager
        self.storageDirectoryOverride = storageDirectory

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadVisits() throws -> [Visit] {
        let url = try visitsFileURL()
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode([Visit].self, from: data)
    }

    func save(visits: [Visit]) throws {
        let url = try visitsFileURL()
        let data = try encoder.encode(visits)
        try data.write(to: url, options: .atomic)
    }

    func loadCaptureRecoverySnapshot() throws -> CaptureRecoverySnapshot? {
        let url = try captureRecoveryFileURL()
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode(CaptureRecoverySnapshot.self, from: data)
    }

    func saveCaptureRecoverySnapshot(_ snapshot: CaptureRecoverySnapshot) throws {
        let url = try captureRecoveryFileURL()
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    func clearCaptureRecoverySnapshot() throws {
        let url = try captureRecoveryFileURL()
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    func exportPackage(visits: [Visit]) throws -> VisitPackage {
        let evidenceDirectory = try evidenceDirectoryURL()
        let recordingsDirectory = try recordingsDirectoryURL()
        return VisitPackage(
            visits: visits.map {
                makeExportVisitCopy(
                    from: $0,
                    evidenceDirectory: evidenceDirectory,
                    recordingsDirectory: recordingsDirectory
                )
            }
        )
    }

    func detectImportConflicts(from url: URL) throws -> [VisitImportConflict] {
        let package = try loadPackage(from: url)
        let localVisitIDs = Set(try loadVisits().map(\.id))
        return package.visits
            .filter { localVisitIDs.contains($0.id) }
            .map { VisitImportConflict(visitID: $0.id, reference: $0.reference) }
    }

    func importPackage(from url: URL, conflictResolution: VisitImportConflictResolution? = nil) throws -> [Visit] {
        let package = try loadPackage(from: url)
        try validate(package: package)

        let existingVisits = try loadVisits()
        let existingVisitIDs = Set(existingVisits.map(\.id))
        let importedConflicts = package.visits.filter { existingVisitIDs.contains($0.id) }
        if !importedConflicts.isEmpty, conflictResolution == nil {
            throw VisitPackageImportError.conflictResolutionRequired
        }

        let resolution = conflictResolution ?? .replaceExistingVisit
        let mergeResult = VisitImportMerger.merge(
            existingVisits: existingVisits,
            importedVisits: package.visits,
            strategy: resolution.contractStrategy
        )
        mergeResult.replacedVisits.forEach(deleteEvidenceFiles(for:))

        let evidenceDir = try evidenceDirectoryURL()
        let recordingsDir = try recordingsDirectoryURL()
        let mergedVisits = try mergeResult.visits
            .map { try restoreStoredFiles(for: $0, evidenceDirectory: evidenceDir, recordingsDirectory: recordingsDir) }

        try save(visits: mergedVisits)
        return mergedVisits
    }

    private func validate(package: VisitPackage) throws {
        if let metadata = package.metadata {
            guard !metadata.exportedByApp.isEmpty, !metadata.source.isEmpty else {
                throw VisitPackageImportError.invalidPackage
            }
        }

        let schemaVersion = package.metadata?.schemaVersion ?? package.schemaVersion
        guard schemaVersion > 0 else {
            throw VisitPackageImportError.invalidPackage
        }
        guard schemaVersion <= Self.supportedSchemaVersion else {
            throw VisitPackageImportError.unsupportedSchemaVersion(schemaVersion)
        }
    }

    private func loadPackage(from url: URL) throws -> VisitPackage {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode(VisitPackage.self, from: data)
    }

    private func restoreStoredFiles(for visit: Visit, evidenceDirectory: URL, recordingsDirectory: URL) throws -> Visit {
        let restoredRooms = try visit.rooms.map { room in
            let restoredEvidence = try room.evidence.map { try restoreEvidence($0, in: evidenceDirectory) }
            return Room(
                id: room.id,
                name: room.name,
                reviewStatus: room.reviewStatus,
                reviewNotes: room.reviewNotes,
                notes: room.notes,
                survey: room.survey,
                evidence: restoredEvidence,
                spatialPlacement: room.spatialPlacement,
                factState: room.factState
            )
        }

        let restoredComponents = try visit.components.map { component in
            let restoredEvidence = try component.evidence.map { try restoreEvidence($0, in: evidenceDirectory) }
            return SystemComponent(
                id: component.id,
                kind: component.kind,
                captureMode: component.captureMode,
                name: component.name,
                manufacturer: component.manufacturer,
                model: component.model,
                notes: component.notes,
                reviewStatus: component.reviewStatus,
                reviewNotes: component.reviewNotes,
                canonicalSubtype: component.canonicalSubtype,
                componentAttributes: component.componentAttributes,
                evidence: restoredEvidence,
                spatialPlacement: component.spatialPlacement,
                factState: component.factState,
                spatialContext: component.spatialContext
            )
        }

        return Visit(
            id: visit.id,
            propertyIdentity: visit.propertyIdentity,
            workingTwin: visit.workingTwin,
            captureSession: visit.captureSession,
            reference: visit.reference,
            createdAt: visit.createdAt,
            twinKind: visit.twinKind,
            customerName: visit.customerName,
            addressLine: visit.addressLine,
            postcode: visit.postcode,
            engineerName: visit.engineerName,
            appointmentDate: visit.appointmentDate,
            notes: visit.notes,
            currentSystemType: visit.currentSystemType,
            captureMode: visit.captureMode,
            rooms: restoredRooms,
            relationships: visit.relationships,
            components: restoredComponents,
            waterSupplyObservations: visit.waterSupplyObservations,
            servicePointObservations: visit.servicePointObservations,
            sectionStatuses: visit.sectionStatuses,
            repositoryState: visit.repositoryState,
            lifecycleStage: visit.lifecycleStage,
            twinVersion: visit.twinVersion,
            lastMergedAt: visit.lastMergedAt,
            changeSetCounters: visit.changeSetCounters,
            recordings: try visit.recordings.map { try restoreRecording($0, in: recordingsDirectory) },
            transcripts: visit.transcripts
        )
    }

    private func makeExportVisitCopy(from visit: Visit, evidenceDirectory: URL, recordingsDirectory: URL) -> Visit {
        let rooms = visit.rooms.map { room in
            var exported = room
            exported.evidence = room.evidence.map { embedEvidenceData($0, from: evidenceDirectory) }
            return exported
        }
        let components = visit.components.map { component in
            var exported = component
            exported.evidence = component.evidence.map { embedEvidenceData($0, from: evidenceDirectory) }
            return exported
        }
        var exported = visit
        exported.rooms = rooms
        exported.components = components
        exported.recordings = visit.recordings.map { embedRecordingData($0, from: recordingsDirectory) }
        return exported
    }

    private func restoreEvidence(_ evidence: Evidence, in evidenceDirectory: URL) throws -> Evidence {
        var restored = evidence
        if let bytes = evidence.embeddedData {
            let fileName = uniqueEvidenceFileName(preferred: evidence.localFileName, in: evidenceDirectory)
            let fileURL = evidenceDirectory.appendingPathComponent(fileName)
            try bytes.write(to: fileURL, options: .atomic)
            restored.localFileName = fileName
        }
        restored.embeddedData = nil
        return restored
    }

    private func restoreRecording(_ recording: VisitRecording, in recordingsDirectory: URL) throws -> VisitRecording {
        var restored = recording
        if let bytes = recording.embeddedData {
            let fileName = uniqueEvidenceFileName(preferred: recording.localFileName, in: recordingsDirectory)
            let fileURL = recordingsDirectory.appendingPathComponent(fileName)
            try bytes.write(to: fileURL, options: .atomic)
            restored.localFileName = fileName
        }
        restored.embeddedData = nil
        return restored
    }

    private func embedEvidenceData(_ evidence: Evidence, from evidenceDirectory: URL) -> Evidence {
        var exported = evidence
        let safeName = URL(fileURLWithPath: evidence.localFileName).lastPathComponent
        if !safeName.isEmpty {
            exported.embeddedData = try? Data(contentsOf: evidenceDirectory.appendingPathComponent(safeName))
        }
        return exported
    }

    private func embedRecordingData(_ recording: VisitRecording, from recordingsDirectory: URL) -> VisitRecording {
        var exported = recording
        let safeName = URL(fileURLWithPath: recording.localFileName).lastPathComponent
        if !safeName.isEmpty {
            exported.embeddedData = try? Data(contentsOf: recordingsDirectory.appendingPathComponent(safeName))
        }
        return exported
    }

    private func uniqueEvidenceFileName(preferred: String, in evidenceDirectory: URL) -> String {
        let fallback = UUID().uuidString
        let preferredName = URL(fileURLWithPath: preferred).lastPathComponent
        var candidate = preferredName.isEmpty ? fallback : preferredName

        let extensionPart = URL(fileURLWithPath: candidate).pathExtension
        let baseName = URL(fileURLWithPath: candidate).deletingPathExtension().lastPathComponent
        var suffix = 2

        while fileManager.fileExists(atPath: evidenceDirectory.appendingPathComponent(candidate).path) {
            if extensionPart.isEmpty {
                candidate = "\(baseName)-\(suffix)"
            } else {
                candidate = "\(baseName)-\(suffix).\(extensionPart)"
            }
            suffix += 1
        }

        return candidate
    }

    func deleteEvidenceFiles(for visit: Visit) {
        guard let dir = try? evidenceDirectoryURL() else { return }
        for room in visit.rooms {
            for evidence in room.evidence where !evidence.localFileName.isEmpty {
                deleteEvidenceFile(named: evidence.localFileName, in: dir)
            }
        }
        for component in visit.components {
            for evidence in component.evidence where !evidence.localFileName.isEmpty {
                deleteEvidenceFile(named: evidence.localFileName, in: dir)
            }
        }
        deleteRecordingFiles(for: visit)
    }

    func deleteEvidenceFile(named fileName: String) {
        guard let dir = try? evidenceDirectoryURL() else { return }
        deleteEvidenceFile(named: fileName, in: dir)
    }

    private func deleteEvidenceFile(named fileName: String, in directory: URL) {
        let safeName = URL(fileURLWithPath: fileName).lastPathComponent
        guard !safeName.isEmpty else { return }
        try? fileManager.removeItem(at: directory.appendingPathComponent(safeName))
    }

    func makeEvidenceFileURL(fileExtension: String, visitID: UUID, roomID: UUID) throws -> URL {
        try makeEvidenceFileURL(fileExtension: fileExtension, visitID: visitID, contextID: roomID)
    }

    func makeEvidenceFileURL(fileExtension: String, visitID: UUID, componentID: UUID) throws -> URL {
        try makeEvidenceFileURL(fileExtension: fileExtension, visitID: visitID, contextID: componentID)
    }

    func evidenceFileURL(localFileName: String) -> URL? {
        guard let directory = try? evidenceDirectoryURL() else { return nil }
        let safeName = URL(fileURLWithPath: localFileName).lastPathComponent
        guard !safeName.isEmpty else { return nil }
        return directory.appendingPathComponent(safeName)
    }

    func makeRecordingFileURL(fileExtension: String = "m4a", visitID: UUID, sequenceNumber: Int) throws -> URL {
        let directory = try recordingsDirectoryURL()
        let fileName = [
            visitID.uuidString,
            "recording",
            String(format: "%03d", sequenceNumber),
            UUID().uuidString
        ]
        .joined(separator: "-") + ".\(fileExtension)"
        return directory.appendingPathComponent(fileName)
    }

    func deleteRecordingFile(named fileName: String) {
        guard let dir = try? recordingsDirectoryURL() else { return }
        deleteEvidenceFile(named: fileName, in: dir)
    }

    private func deleteRecordingFiles(for visit: Visit) {
        guard let dir = try? recordingsDirectoryURL() else { return }
        for recording in visit.recordings where !recording.localFileName.isEmpty {
            deleteEvidenceFile(named: recording.localFileName, in: dir)
        }
    }

    private func makeEvidenceFileURL(fileExtension: String, visitID: UUID, contextID: UUID) throws -> URL {
        let directory = try evidenceDirectoryURL()
        let fileName = [visitID.uuidString, contextID.uuidString, UUID().uuidString]
            .joined(separator: "-") + ".\(fileExtension)"
        return directory.appendingPathComponent(fileName)
    }

    private func visitsFileURL() throws -> URL {
        try storageDirectoryURL().appendingPathComponent("visits.json")
    }

    private func captureRecoveryFileURL() throws -> URL {
        try storageDirectoryURL().appendingPathComponent("capture-recovery.json")
    }

    private func evidenceDirectoryURL() throws -> URL {
        let directory = try storageDirectoryURL().appendingPathComponent("Evidence", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private func recordingsDirectoryURL() throws -> URL {
        let directory = try storageDirectoryURL().appendingPathComponent("Recordings", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private func storageDirectoryURL() throws -> URL {
        if let storageDirectoryOverride {
            if !fileManager.fileExists(atPath: storageDirectoryOverride.path) {
                try fileManager.createDirectory(at: storageDirectoryOverride, withIntermediateDirectories: true)
            }
            return storageDirectoryOverride
        }

        let baseDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let storageDirectory = baseDirectory.appendingPathComponent("DaedalusScan", isDirectory: true)
        if !fileManager.fileExists(atPath: storageDirectory.path) {
            try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        }
        return storageDirectory
    }
}

private extension VisitImportConflictResolution {
    var contractStrategy: VisitImportConflictStrategy {
        switch self {
        case .replaceExistingVisit:
            return .replaceExistingVisit
        case .keepBoth:
            return .keepBoth
        }
    }
}
