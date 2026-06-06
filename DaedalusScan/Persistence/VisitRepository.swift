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
            return "This package conflicts with existing visits. Choose how to continue import."
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

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

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

    func exportPackage(visits: [Visit]) -> VisitPackage {
        let evidenceDir = try? evidenceDirectoryURL()
        let embeddedVisits = visits.map { visit -> Visit in
            var v = visit
            v.rooms = visit.rooms.map { room -> Room in
                var r = room
                r.evidence = room.evidence.map { evidence -> Evidence in
                    guard let dir = evidenceDir, !evidence.localFileName.isEmpty else { return evidence }
                    var e = evidence
                    e.embeddedData = try? Data(contentsOf: dir.appendingPathComponent(evidence.localFileName))
                    return e
                }
                return r
            }
            v.components = visit.components.map { component -> SystemComponent in
                var c = component
                c.evidence = component.evidence.map { evidence -> Evidence in
                    guard let dir = evidenceDir, !evidence.localFileName.isEmpty else { return evidence }
                    var e = evidence
                    e.embeddedData = try? Data(contentsOf: dir.appendingPathComponent(evidence.localFileName))
                    return e
                }
                return c
            }
            return v
        }
        let exportDate = Date()
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let metadata = VisitPackageMetadata(
            schemaVersion: Self.supportedSchemaVersion,
            createdAt: exportDate,
            exportedByApp: VisitPackageMetadata.canonicalSource,
            appVersion: appVersion,
            source: VisitPackageMetadata.canonicalSource
        )
        return VisitPackage(metadata: metadata, exportedAt: exportDate, visits: embeddedVisits)
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
        let mergedVisits = try mergeResult.visits
            .map { try restoreEvidence(for: $0, evidenceDirectory: evidenceDir) }

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

    private func restoreEvidence(for visit: Visit, evidenceDirectory: URL) throws -> Visit {
        let restoredRooms = try visit.rooms.map { room in
            let restoredEvidence = try room.evidence.map { try restoreEvidence($0, in: evidenceDirectory) }
            return Room(
                id: room.id,
                name: room.name,
                reviewStatus: room.reviewStatus,
                reviewNotes: room.reviewNotes,
                notes: room.notes,
                survey: room.survey,
                evidence: restoredEvidence
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
                componentAttributes: component.componentAttributes,
                evidence: restoredEvidence
            )
        }

        return Visit(
            id: visit.id,
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
            proposedSystemType: visit.proposedSystemType,
            captureMode: visit.captureMode,
            rooms: restoredRooms,
            components: restoredComponents,
            sectionStatuses: visit.sectionStatuses,
            proposedSectionStatuses: visit.proposedSectionStatuses
        )
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
                try? fileManager.removeItem(at: dir.appendingPathComponent(evidence.localFileName))
            }
        }
        for component in visit.components {
            for evidence in component.evidence where !evidence.localFileName.isEmpty {
                try? fileManager.removeItem(at: dir.appendingPathComponent(evidence.localFileName))
            }
        }
    }

    func makeEvidenceFileURL(fileExtension: String, visitID: UUID, roomID: UUID) throws -> URL {
        try makeEvidenceFileURL(fileExtension: fileExtension, visitID: visitID, contextID: roomID)
    }

    func makeEvidenceFileURL(fileExtension: String, visitID: UUID, componentID: UUID) throws -> URL {
        try makeEvidenceFileURL(fileExtension: fileExtension, visitID: visitID, contextID: componentID)
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

    private func evidenceDirectoryURL() throws -> URL {
        let directory = try storageDirectoryURL().appendingPathComponent("Evidence", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private func storageDirectoryURL() throws -> URL {
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
