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
        data: Data(#"{"captured_at":"1970-01-01T00:00:00Z","observations":[],"packageId":"00000000-0000-0000-0000-000000000000","packageVersion":4,"propertyRef":"empty","propertyRoots":[],"relationships":[],"visitId":"00000000-0000-0000-0000-000000000000"}"#.utf8)
    )

    private init(data: Data) {
        self.data = data
    }

    init<Package: Encodable>(package: Package) throws {
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
