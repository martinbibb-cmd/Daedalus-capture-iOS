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

public enum SystemComponentKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case boiler
    case flue
    case controls
    case cylinder
    case feedAndExpansion
    case gasMeter
    case radiator
    case pump
    case pipework
    case other

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .boiler:
            return "Boiler"
        case .flue:
            return "Flue"
        case .controls:
            return "Controls"
        case .cylinder:
            return "Cylinder"
        case .feedAndExpansion:
            return "Feed & Expansion"
        case .gasMeter:
            return "Gas Meter"
        case .radiator:
            return "Radiator"
        case .pump:
            return "Pump"
        case .pipework:
            return "Pipework"
        case .other:
            return "Other"
        }
    }

    /// Canonical survey traversal order for system-first capture.
    public static let canonicalOrder: [SystemComponentKind] = [
        .boiler,
        .flue,
        .controls,
        .cylinder,
        .feedAndExpansion,
        .gasMeter,
        .radiator,
        .pump,
        .pipework,
        .other
    ]
}

public struct SystemComponent: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var kind: SystemComponentKind
    public var name: String
    public var manufacturer: String
    public var model: String
    public var notes: String
    public var evidence: [Evidence]

    public init(
        id: UUID = UUID(),
        kind: SystemComponentKind,
        name: String = "",
        manufacturer: String = "",
        model: String = "",
        notes: String = "",
        evidence: [Evidence] = []
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.manufacturer = manufacturer
        self.model = model
        self.notes = notes
        self.evidence = evidence
    }
}

public struct Visit: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var reference: String
    public var createdAt: Date
    public var twinKind: TwinKind
    public var rooms: [Room]
    public var components: [SystemComponent]

    public init(
        id: UUID = UUID(),
        reference: String,
        createdAt: Date = Date(),
        twinKind: TwinKind,
        rooms: [Room] = [],
        components: [SystemComponent] = []
    ) {
        self.id = id
        self.reference = reference
        self.createdAt = createdAt
        self.twinKind = twinKind
        self.rooms = rooms
        self.components = components
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case reference
        case createdAt
        case twinKind
        case rooms
        case components
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        reference = try container.decode(String.self, forKey: .reference)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        twinKind = try container.decode(TwinKind.self, forKey: .twinKind)
        rooms = try container.decode([Room].self, forKey: .rooms)
        components = try container.decodeIfPresent([SystemComponent].self, forKey: .components) ?? []
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
