import DaedalusContracts
import Foundation

enum VisitPackageImportError: LocalizedError {
    case invalidPackage
    case unsupportedSchemaVersion(Int)

    var errorDescription: String? {
        switch self {
        case .invalidPackage:
            return "The selected package is invalid."
        case let .unsupportedSchemaVersion(version):
            return "This package was created with an unsupported schema version (\(version))."
        }
    }
}

@MainActor
final class VisitRepository {
    private static let supportedSchemaVersion = VisitPackageMetadata.currentSchemaVersion

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
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

    func importPackage(from url: URL) throws -> [Visit] {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        let package = try decoder.decode(VisitPackage.self, from: data)
        try validate(package: package)

        let evidenceDir = try? evidenceDirectoryURL()
        let restoredVisits = package.visits.map { visit -> Visit in
            var v = visit
            v.rooms = visit.rooms.map { room -> Room in
                var r = room
                r.evidence = room.evidence.map { evidence -> Evidence in
                    var e = evidence
                    if let dir = evidenceDir,
                       let bytes = evidence.embeddedData,
                       !evidence.localFileName.isEmpty {
                        let fileURL = dir.appendingPathComponent(evidence.localFileName)
                        try? bytes.write(to: fileURL, options: .atomic)
                    }
                    e.embeddedData = nil
                    return e
                }
                return r
            }
            v.components = visit.components.map { component -> SystemComponent in
                var c = component
                c.evidence = component.evidence.map { evidence -> Evidence in
                    var e = evidence
                    if let dir = evidenceDir,
                       let bytes = evidence.embeddedData,
                       !evidence.localFileName.isEmpty {
                        let fileURL = dir.appendingPathComponent(evidence.localFileName)
                        try? bytes.write(to: fileURL, options: .atomic)
                    }
                    e.embeddedData = nil
                    return e
                }
                return c
            }
            return v
        }

        try save(visits: restoredVisits)
        return restoredVisits
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
