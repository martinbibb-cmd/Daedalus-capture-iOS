import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let daedalusScanPackage = UTType(exportedAs: "com.daedalus.scan.package", conformingTo: .json)
}

struct VisitExportDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.daedalusScanPackage, .json]
    }

    let data: Data

    static let empty = VisitExportDocument(
        data: Data(#"{"exportedAt":"1970-01-01T00:00:00Z","metadata":{"appVersion":null,"createdAt":"1970-01-01T00:00:00Z","exportedByApp":"Daedalus Scan","packageID":"00000000-0000-0000-0000-000000000000","schemaVersion":1,"source":"Daedalus Scan"},"schemaVersion":1,"visits":[]}"#.utf8)
    )

    private init(data: Data) {
        self.data = data
    }

    init(package: VisitPackage) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.data = try encoder.encode(package)
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
