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
        .pipework,
        .pump,
        .other
    ]
}

public enum SectionStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case notChecked
    case present
    case notPresent
    case unknown
    case notAccessible

    public var title: String {
        switch self {
        case .notChecked: return "Not Checked"
        case .present: return "Present"
        case .notPresent: return "Not Present"
        case .unknown: return "Unknown"
        case .notAccessible: return "Not Accessible"
        }
    }
}

public enum ComponentAttributeFieldKind: Hashable, Sendable {
    case text
    case multiline
    case singleChoice([String])
}

public struct ComponentAttributeField: Hashable, Identifiable, Sendable {
    public let key: String
    public let label: String
    public let kind: ComponentAttributeFieldKind

    public var id: String { key }

    public init(key: String, label: String, kind: ComponentAttributeFieldKind) {
        self.key = key
        self.label = label
        self.kind = kind
    }
}

public enum ComponentObservedValue: String, Codable, CaseIterable, Sendable {
    case unknown = "Unknown"
    case observed = "Observed"
    case notObserved = "Not Observed"
}

public enum ComponentAccessibilityValue: String, Codable, CaseIterable, Sendable {
    case unknown = "Unknown"
    case accessible = "Accessible"
    case restricted = "Restricted"
    case notAccessible = "Not Accessible"
}

public extension SystemComponentKind {
    var attributeFields: [ComponentAttributeField] {
        switch self {
        case .boiler:
            return [
                ComponentAttributeField(key: "fuelType", label: "Fuel type", kind: .text),
                ComponentAttributeField(key: "boilerType", label: "Boiler type", kind: .text),
                ComponentAttributeField(key: "approximateAge", label: "Approximate age", kind: .text),
                ComponentAttributeField(key: "location", label: "Location", kind: .text),
                ComponentAttributeField(key: "fluePositionNotes", label: "Flue position notes", kind: .multiline),
                ComponentAttributeField(key: "visibleConditionNotes", label: "Visible condition notes", kind: .multiline)
            ]
        case .flue:
            return [
                ComponentAttributeField(key: "terminalLocation", label: "Terminal location", kind: .text),
                ComponentAttributeField(key: "approximateRoute", label: "Approximate route", kind: .multiline),
                ComponentAttributeField(key: "visibleClearanceConcernsNote", label: "Visible clearance concerns note", kind: .multiline),
                ComponentAttributeField(key: "plumeNotes", label: "Plume notes", kind: .multiline)
            ]
        case .controls:
            return [
                ComponentAttributeField(key: "programmerPresent", label: "Programmer present", kind: .singleChoice(ComponentObservedValue.allCases.map(\.rawValue))),
                ComponentAttributeField(key: "roomThermostatPresent", label: "Room thermostat present", kind: .singleChoice(ComponentObservedValue.allCases.map(\.rawValue))),
                ComponentAttributeField(key: "smartControlPresent", label: "Smart control present", kind: .singleChoice(ComponentObservedValue.allCases.map(\.rawValue))),
                ComponentAttributeField(key: "zoneValvesObserved", label: "Zone valves observed", kind: .singleChoice(ComponentObservedValue.allCases.map(\.rawValue)))
            ]
        case .cylinder:
            return [
                ComponentAttributeField(key: "cylinderType", label: "Cylinder type", kind: .text),
                ComponentAttributeField(key: "location", label: "Location", kind: .text),
                ComponentAttributeField(key: "approximateCapacityVisible", label: "Approximate capacity if visible", kind: .text),
                ComponentAttributeField(
                    key: "observedConfiguration",
                    label: "Vented / unvented / thermal store observed",
                    kind: .singleChoice(["Unknown", "Vented", "Unvented", "Thermal Store"])
                )
            ]
        case .feedAndExpansion:
            return [
                ComponentAttributeField(key: "location", label: "Location", kind: .text),
                ComponentAttributeField(key: "tankConditionNotes", label: "Tank condition notes", kind: .multiline),
                ComponentAttributeField(key: "accessibility", label: "Accessibility", kind: .singleChoice(ComponentAccessibilityValue.allCases.map(\.rawValue)))
            ]
        case .gasMeter:
            return [
                ComponentAttributeField(key: "location", label: "Location", kind: .text),
                ComponentAttributeField(key: "visibleECV", label: "Visible ECV", kind: .singleChoice(ComponentObservedValue.allCases.map(\.rawValue))),
                ComponentAttributeField(key: "bondingObserved", label: "Bonding observed", kind: .singleChoice(ComponentObservedValue.allCases.map(\.rawValue)))
            ]
        case .radiator:
            return [
                ComponentAttributeField(key: "roomOrLocation", label: "Room / location", kind: .text),
                ComponentAttributeField(key: "typeSizeNotes", label: "Type / size notes", kind: .multiline),
                ComponentAttributeField(key: "valvesObserved", label: "Valves observed", kind: .multiline)
            ]
        case .pump:
            return [
                ComponentAttributeField(key: "location", label: "Location", kind: .text),
                ComponentAttributeField(key: "visibleModel", label: "Visible model", kind: .text),
                ComponentAttributeField(key: "directionValveNotes", label: "Direction / valve notes", kind: .multiline)
            ]
        case .pipework:
            return [
                ComponentAttributeField(key: "visibleMaterial", label: "Visible material", kind: .text),
                ComponentAttributeField(key: "routeNotes", label: "Route notes", kind: .multiline),
                ComponentAttributeField(key: "conditionNotes", label: "Condition notes", kind: .multiline)
            ]
        case .other:
            return [
                ComponentAttributeField(key: "freeCaptureNotes", label: "Free capture notes", kind: .multiline)
            ]
        }
    }
}

public struct SystemComponent: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var kind: SystemComponentKind
    public var name: String
    public var manufacturer: String
    public var model: String
    public var notes: String
    public var componentAttributes: [String: String]
    public var evidence: [Evidence]

    public init(
        id: UUID = UUID(),
        kind: SystemComponentKind,
        name: String = "",
        manufacturer: String = "",
        model: String = "",
        notes: String = "",
        componentAttributes: [String: String] = [:],
        evidence: [Evidence] = []
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.manufacturer = manufacturer
        self.model = model
        self.notes = notes
        self.componentAttributes = componentAttributes
        self.evidence = evidence
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case name
        case manufacturer
        case model
        case notes
        case componentAttributes
        case evidence
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(SystemComponentKind.self, forKey: .kind)
        name = try container.decode(String.self, forKey: .name)
        manufacturer = try container.decode(String.self, forKey: .manufacturer)
        model = try container.decode(String.self, forKey: .model)
        notes = try container.decode(String.self, forKey: .notes)
        componentAttributes = try container.decodeIfPresent([String: String].self, forKey: .componentAttributes) ?? [:]
        evidence = try container.decodeIfPresent([Evidence].self, forKey: .evidence) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(name, forKey: .name)
        try container.encode(manufacturer, forKey: .manufacturer)
        try container.encode(model, forKey: .model)
        try container.encode(notes, forKey: .notes)
        try container.encode(componentAttributes, forKey: .componentAttributes)
        try container.encode(evidence, forKey: .evidence)
    }
}

public struct Visit: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var reference: String
    public var createdAt: Date
    public var twinKind: TwinKind
    public var rooms: [Room]
    public var components: [SystemComponent]
    public var sectionStatuses: [SystemComponentKind: SectionStatus]

    public init(
        id: UUID = UUID(),
        reference: String,
        createdAt: Date = Date(),
        twinKind: TwinKind,
        rooms: [Room] = [],
        components: [SystemComponent] = [],
        sectionStatuses: [SystemComponentKind: SectionStatus] = [:]
    ) {
        self.id = id
        self.reference = reference
        self.createdAt = createdAt
        self.twinKind = twinKind
        self.rooms = rooms
        self.components = components
        self.sectionStatuses = sectionStatuses
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case reference
        case createdAt
        case twinKind
        case rooms
        case components
        case sectionStatuses
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        reference = try container.decode(String.self, forKey: .reference)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        twinKind = try container.decode(TwinKind.self, forKey: .twinKind)
        rooms = try container.decode([Room].self, forKey: .rooms)
        components = try container.decodeIfPresent([SystemComponent].self, forKey: .components) ?? []
        sectionStatuses = try container.decodeIfPresent([SystemComponentKind: SectionStatus].self, forKey: .sectionStatuses) ?? [:]
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
