import Foundation

public enum TwinKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case house
    case home

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system:
            return "System Twin"
        case .house:
            return "House Twin"
        case .home:
            return "Home Twin"
        }
    }
}

public enum SurveyFieldKind: String, Codable, CaseIterable, Sendable {
    case boolean
    case singleChoice
    case numeric
}

public struct SurveyQuestion: Codable, Hashable, Identifiable, Sendable {
    public let key: String
    public let label: String
    public let kind: SurveyFieldKind
    public let allowedValues: [String]

    public var id: String { key }

    public init(key: String, label: String, kind: SurveyFieldKind, allowedValues: [String] = []) {
        self.key = key
        self.label = label
        self.kind = kind
        self.allowedValues = allowedValues
    }
}

public struct SurveyResponse: Codable, Hashable, Sendable {
    public var booleanValue: Bool?
    public var selectedValue: String?
    public var numericValue: Double?

    public init(booleanValue: Bool? = nil, selectedValue: String? = nil, numericValue: Double? = nil) {
        self.booleanValue = booleanValue
        self.selectedValue = selectedValue
        self.numericValue = numericValue
    }

    public func isAnswered(for question: SurveyQuestion) -> Bool {
        switch question.kind {
        case .boolean:
            return booleanValue != nil
        case .singleChoice:
            return !(selectedValue?.isEmpty ?? true)
        case .numeric:
            return numericValue != nil
        }
    }
}

public enum EvidenceKind: String, Codable, CaseIterable, Sendable {
    case photo
    case voiceNote
    case textNote
}

public struct Evidence: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var kind: EvidenceKind
    public var localFileName: String
    public var createdAt: Date
    /// Embedded file bytes included in an exported VisitPackage to enable round-trip restore.
    /// Nil when stored locally; populated by the exporter and consumed by the importer.
    public var embeddedData: Data?

    public init(
        id: UUID = UUID(),
        kind: EvidenceKind,
        localFileName: String,
        createdAt: Date = Date(),
        embeddedData: Data? = nil
    ) {
        self.id = id
        self.kind = kind
        self.localFileName = localFileName
        self.createdAt = createdAt
        self.embeddedData = embeddedData
    }
}

public struct Room: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var survey: [String: SurveyResponse]
    public var evidence: [Evidence]

    public init(id: UUID = UUID(), name: String, survey: [String: SurveyResponse] = [:], evidence: [Evidence] = []) {
        self.id = id
        self.name = name
        self.survey = survey
        self.evidence = evidence
    }
}

public struct Visit: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var reference: String
    public var createdAt: Date
    public var twinKind: TwinKind
    public var rooms: [Room]

    public init(id: UUID = UUID(), reference: String, createdAt: Date = Date(), twinKind: TwinKind, rooms: [Room] = []) {
        self.id = id
        self.reference = reference
        self.createdAt = createdAt
        self.twinKind = twinKind
        self.rooms = rooms
    }
}

public struct VisitPackage: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var exportedAt: Date
    public var visits: [Visit]

    public init(schemaVersion: Int = 1, exportedAt: Date = Date(), visits: [Visit]) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.visits = visits
    }
}

public enum DaedalusCatalog {
    public static let defaultSurvey: [SurveyQuestion] = [
        SurveyQuestion(
            key: "heating.emitters.present",
            label: "Emitters present",
            kind: .boolean
        ),
        SurveyQuestion(
            key: "heating.system.type",
            label: "Heating system type",
            kind: .singleChoice,
            allowedValues: ["Boiler", "Heat Pump", "Direct Electric", "Unknown"]
        ),
        SurveyQuestion(
            key: "ventilation.extract.count",
            label: "Extract fan count",
            kind: .numeric
        )
    ]
}
