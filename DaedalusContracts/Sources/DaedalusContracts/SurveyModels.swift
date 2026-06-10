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

public enum HeatingSystemType: String, Codable, CaseIterable, Hashable, Sendable {
    case combi
    case regularSealed
    case regularOpenVented
    case unknown

    public var title: String {
        switch self {
        case .combi:
            return "Combi"
        case .regularSealed:
            return "Regular/System (Cylinder)"
        case .regularOpenVented:
            return "Regular/Open-Vented"
        case .unknown:
            return "Unknown"
        }
    }
}

public enum CaptureMode: String, Codable, CaseIterable, Hashable, Sendable {
    case create
    case verify
    case update

    public var title: String {
        switch self {
        case .create:
            return "Create Twin"
        case .verify:
            return "Verify Twin"
        case .update:
            return "Update Twin"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case Self.create.rawValue, "current":
            self = .create
        case Self.verify.rawValue:
            self = .verify
        case Self.update.rawValue, "pro" + "posed":
            self = .update
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown capture mode: \(rawValue)"
            )
        }
    }
}

public enum TwinRepositoryState: String, Codable, CaseIterable, Hashable, Sendable {
    case authoritativeCloudTwin
    case localWorkingCopy
    case hasLocalChanges
    case stagedForReview
    case awaitingClarification
    case readyToMerge
    case merged

    public var title: String {
        switch self {
        case .authoritativeCloudTwin: return "Authoritative Twin"
        case .localWorkingCopy: return "Working Twin"
        case .hasLocalChanges: return "Working Twin"
        case .stagedForReview: return "In Review"
        case .awaitingClarification: return "Needs Clarification"
        case .readyToMerge: return "Ready to Merge"
        case .merged: return "Merged Twin"
        }
    }
}

public enum TwinLifecycleStage: String, Codable, CaseIterable, Hashable, Sendable {
    case pull
    case capture
    case commit
    case stage
    case clarify
    case recapture
    case confirm
    case merge

    public var title: String {
        switch self {
        case .pull: return "Pull Twin"
        case .capture: return "Capture"
        case .commit: return "Commit"
        case .stage: return "Review"
        case .clarify: return "Clarify"
        case .recapture: return "Recapture"
        case .confirm: return "Confirm"
        case .merge: return "Merge Twin"
        }
    }
}

public enum TwinFactState: String, Codable, CaseIterable, Hashable, Sendable {
    case known
    case estimated
    case inferred
    case unknown

    public var title: String {
        switch self {
        case .known: return "Known"
        case .estimated: return "Estimated"
        case .inferred: return "Inferred"
        case .unknown: return "Unknown"
        }
    }
}

public enum EvidenceTrustLevel: Int, Codable, CaseIterable, Hashable, Sendable {
    case reality = 1
    case photos = 2
    case documents = 3
    case measurements = 4
    case humanObservations = 5
    case twinData = 6

    public var title: String {
        switch self {
        case .reality: return "Reality"
        case .photos: return "Photos"
        case .documents: return "Documents"
        case .measurements: return "Measurements"
        case .humanObservations: return "Human Observations"
        case .twinData: return "Twin Data"
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
    public var reviewStatus: ReviewStatus?
    public var reviewNotes: String?

    public init(
        booleanValue: Bool? = nil,
        selectedValue: String? = nil,
        numericValue: Double? = nil,
        reviewStatus: ReviewStatus? = nil,
        reviewNotes: String? = nil
    ) {
        self.booleanValue = booleanValue
        self.selectedValue = selectedValue
        self.numericValue = numericValue
        self.reviewStatus = reviewStatus
        self.reviewNotes = reviewNotes
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

public enum ReviewStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case draft
    case needsReview
    case confirmed
    case rejected

    public var title: String {
        switch self {
        case .draft: return "Draft"
        case .needsReview: return "Needs review"
        case .confirmed: return "Confirmed"
        case .rejected: return "Rejected"
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
    public var reviewStatus: ReviewStatus?
    public var reviewNotes: String?
    public var trustLevel: EvidenceTrustLevel
    /// Embedded file bytes included in an exported VisitPackage to enable round-trip restore.
    /// Nil when stored locally; populated by the exporter and consumed by the importer.
    public var embeddedData: Data?

    public init(
        id: UUID = UUID(),
        kind: EvidenceKind,
        localFileName: String,
        createdAt: Date = Date(),
        reviewStatus: ReviewStatus? = nil,
        reviewNotes: String? = nil,
        trustLevel: EvidenceTrustLevel? = nil,
        embeddedData: Data? = nil
    ) {
        self.id = id
        self.kind = kind
        self.localFileName = localFileName
        self.createdAt = createdAt
        self.reviewStatus = reviewStatus
        self.reviewNotes = reviewNotes
        self.trustLevel = trustLevel ?? kind.defaultTrustLevel
        self.embeddedData = embeddedData
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case localFileName
        case createdAt
        case reviewStatus
        case reviewNotes
        case trustLevel
        case embeddedData
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(EvidenceKind.self, forKey: .kind)
        localFileName = try container.decode(String.self, forKey: .localFileName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        reviewStatus = try container.decodeIfPresent(ReviewStatus.self, forKey: .reviewStatus)
        reviewNotes = try container.decodeIfPresent(String.self, forKey: .reviewNotes)
        trustLevel = try container.decodeIfPresent(EvidenceTrustLevel.self, forKey: .trustLevel) ?? kind.defaultTrustLevel
        embeddedData = try container.decodeIfPresent(Data.self, forKey: .embeddedData)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(localFileName, forKey: .localFileName)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(reviewStatus, forKey: .reviewStatus)
        try container.encodeIfPresent(reviewNotes, forKey: .reviewNotes)
        try container.encode(trustLevel, forKey: .trustLevel)
        try container.encodeIfPresent(embeddedData, forKey: .embeddedData)
    }
}

public extension EvidenceKind {
    var defaultTrustLevel: EvidenceTrustLevel {
        switch self {
        case .photo: return .photos
        case .voiceNote, .textNote: return .humanObservations
        }
    }
}

public enum SpatialCaptureState: String, Codable, CaseIterable, Hashable, Sendable {
    case unspecified
    case anchored
    case approximate
    case areaReferenceOnly
    case failed

    public var title: String {
        switch self {
        case .unspecified: return "Unspecified"
        case .anchored: return "Anchored"
        case .approximate: return "Approximate"
        case .areaReferenceOnly: return "Area Reference Only"
        case .failed: return "Spatial Capture Failed"
        }
    }
}

public enum SpatialConfidence: String, Codable, CaseIterable, Hashable, Sendable {
    case unknown
    case low
    case medium
    case high

    public var title: String {
        rawValue.capitalized
    }
}

public struct SpatialPosition: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}

public struct SpatialPlacement: Codable, Hashable, Sendable {
    public var anchorID: String?
    public var approximatePosition: SpatialPosition?
    public var captureState: SpatialCaptureState
    public var confidence: SpatialConfidence

    public init(
        anchorID: String? = nil,
        approximatePosition: SpatialPosition? = nil,
        captureState: SpatialCaptureState = .unspecified,
        confidence: SpatialConfidence = .unknown
    ) {
        self.anchorID = anchorID
        self.approximatePosition = approximatePosition
        self.captureState = captureState
        self.confidence = confidence
    }
}

public struct SpatialEvidenceContext: Codable, Hashable, Sendable {
    public var floorLevel: String
    public var areaLabel: String
    public var geometryID: String?
    public var approximatePositionLabel: String?

    public init(
        floorLevel: String = "Unknown level",
        areaLabel: String = "Spatial capture",
        geometryID: String? = nil,
        approximatePositionLabel: String? = nil
    ) {
        self.floorLevel = floorLevel
        self.areaLabel = areaLabel
        self.geometryID = geometryID
        self.approximatePositionLabel = approximatePositionLabel
    }
}

public enum SpatialRelationshipType: String, Codable, CaseIterable, Identifiable, Sendable {
    case containedIn
    case connectedTo
    case controls
    case supplies
    case serves

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .containedIn: return "Contained In"
        case .connectedTo: return "Connected To"
        case .controls: return "Controls"
        case .supplies: return "Supplies"
        case .serves: return "Serves"
        }
    }
}

public struct SpatialRelationship: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var sourceComponentID: UUID
    public var relationship: SpatialRelationshipType
    public var targetComponentID: UUID?
    public var targetAreaID: UUID?

    public init(
        id: UUID = UUID(),
        sourceComponentID: UUID,
        relationship: SpatialRelationshipType,
        targetComponentID: UUID? = nil,
        targetAreaID: UUID? = nil
    ) {
        self.id = id
        self.sourceComponentID = sourceComponentID
        self.relationship = relationship
        self.targetComponentID = targetComponentID
        self.targetAreaID = targetAreaID
    }
}

public struct Room: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var reviewStatus: ReviewStatus?
    public var reviewNotes: String?
    public var notes: String
    public var survey: [String: SurveyResponse]
    public var evidence: [Evidence]
    public var spatialPlacement: SpatialPlacement
    public var factState: TwinFactState

    public init(
        id: UUID = UUID(),
        name: String,
        reviewStatus: ReviewStatus? = nil,
        reviewNotes: String? = nil,
        notes: String = "",
        survey: [String: SurveyResponse] = [:],
        evidence: [Evidence] = [],
        spatialPlacement: SpatialPlacement = SpatialPlacement(),
        factState: TwinFactState = .unknown
    ) {
        self.id = id
        self.name = name
        self.reviewStatus = reviewStatus
        self.reviewNotes = reviewNotes
        self.notes = notes
        self.survey = survey
        self.evidence = evidence
        self.spatialPlacement = spatialPlacement
        self.factState = factState
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case reviewStatus
        case reviewNotes
        case notes
        case survey
        case evidence
        case spatialPlacement
        case factState
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        reviewStatus = try container.decodeIfPresent(ReviewStatus.self, forKey: .reviewStatus)
        reviewNotes = try container.decodeIfPresent(String.self, forKey: .reviewNotes)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        survey = try container.decodeIfPresent([String: SurveyResponse].self, forKey: .survey) ?? [:]
        evidence = try container.decodeIfPresent([Evidence].self, forKey: .evidence) ?? []
        spatialPlacement = try container.decodeIfPresent(SpatialPlacement.self, forKey: .spatialPlacement) ?? SpatialPlacement()
        factState = try container.decodeIfPresent(TwinFactState.self, forKey: .factState) ?? .unknown
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(reviewStatus, forKey: .reviewStatus)
        try container.encodeIfPresent(reviewNotes, forKey: .reviewNotes)
        try container.encode(notes, forKey: .notes)
        try container.encode(survey, forKey: .survey)
        try container.encode(evidence, forKey: .evidence)
        try container.encode(spatialPlacement, forKey: .spatialPlacement)
        try container.encode(factState, forKey: .factState)
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

    public var surveyTitle: String {
        switch self {
        case .radiator:
            return "Emitters"
        default:
            return title
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

public enum SystemComponentCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case heatSource
    case hotWater
    case emitter
    case control
    case infrastructure
    case unknown

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .heatSource: return "Heat Source"
        case .hotWater: return "Hot Water"
        case .emitter: return "Emitters"
        case .control: return "Controls"
        case .infrastructure: return "Infrastructure"
        case .unknown: return "Unknown"
        }
    }
}

public enum SystemComponentSubtype: String, Codable, CaseIterable, Identifiable, Sendable {
    case regularBoiler
    case systemBoiler
    case combiBoiler
    case ashp
    case otherHeatSource
    case unknownHeatSource
    case unventedCylinder
    case ventedCylinder
    case thermalStore
    case coldWaterStorage
    case feedAndExpansion
    case directCombiDHW
    case unknownHotWater
    case radiatorUncontrolled
    case radiatorTRVControlled
    case radiatorInRoomStatZone
    case radiatorTRVControlledInRoomStatZone
    case towelRail
    case towelRailTRVControlled
    case ufhSingleZone
    case ufhZoned
    case ufhDedicatedRoomStat
    case fanConvector
    case unknownEmitter
    case programmer
    case roomThermostat
    case smartThermostat
    case trv
    case zoneValve
    case weatherCompensation
    case unknownControl
    case gasMeter
    case waterMain
    case stopTap
    case flueTerminal
    case condensateRoute
    case pump
    case magneticFilter
    case otherInfrastructure
    case unknownInfrastructure

    public var id: String { rawValue }

    public var category: SystemComponentCategory {
        switch self {
        case .regularBoiler, .systemBoiler, .combiBoiler, .ashp, .otherHeatSource, .unknownHeatSource:
            return .heatSource
        case .unventedCylinder, .ventedCylinder, .thermalStore, .coldWaterStorage, .feedAndExpansion, .directCombiDHW, .unknownHotWater:
            return .hotWater
        case .radiatorUncontrolled, .radiatorTRVControlled, .radiatorInRoomStatZone, .radiatorTRVControlledInRoomStatZone, .towelRail, .towelRailTRVControlled, .ufhSingleZone, .ufhZoned, .ufhDedicatedRoomStat, .fanConvector, .unknownEmitter:
            return .emitter
        case .programmer, .roomThermostat, .smartThermostat, .trv, .zoneValve, .weatherCompensation, .unknownControl:
            return .control
        case .gasMeter, .waterMain, .stopTap, .flueTerminal, .condensateRoute, .pump, .magneticFilter, .otherInfrastructure, .unknownInfrastructure:
            return .infrastructure
        }
    }

    public var title: String {
        switch self {
        case .regularBoiler: return "Regular Boiler"
        case .systemBoiler: return "System Boiler"
        case .combiBoiler: return "Combi Boiler"
        case .ashp: return "ASHP"
        case .otherHeatSource: return "Other Heat Source"
        case .unknownHeatSource: return "Unknown Heat Source"
        case .unventedCylinder: return "Unvented Cylinder"
        case .ventedCylinder: return "Vented Cylinder"
        case .thermalStore: return "Thermal Store"
        case .coldWaterStorage: return "Cold Water Storage"
        case .feedAndExpansion: return "Feed & Expansion"
        case .directCombiDHW: return "Direct Combi DHW"
        case .unknownHotWater: return "Unknown Hot Water"
        case .radiatorUncontrolled: return "Radiator Uncontrolled"
        case .radiatorTRVControlled: return "Radiator TRV Controlled"
        case .radiatorInRoomStatZone: return "Radiator In Room Stat Zone"
        case .radiatorTRVControlledInRoomStatZone: return "Radiator TRV Controlled In Room Stat Zone"
        case .towelRail: return "Towel Rail"
        case .towelRailTRVControlled: return "Towel Rail TRV Controlled"
        case .ufhSingleZone: return "UFH Single Zone"
        case .ufhZoned: return "UFH Zoned"
        case .ufhDedicatedRoomStat: return "UFH Dedicated Room Stat"
        case .fanConvector: return "Fan Convector"
        case .unknownEmitter: return "Unknown Emitter"
        case .programmer: return "Programmer"
        case .roomThermostat: return "Room Thermostat"
        case .smartThermostat: return "Smart Thermostat"
        case .trv: return "TRV"
        case .zoneValve: return "Zone Valve"
        case .weatherCompensation: return "Weather Compensation"
        case .unknownControl: return "Unknown Control"
        case .gasMeter: return "Gas Meter"
        case .waterMain: return "Water Main"
        case .stopTap: return "Stop Tap"
        case .flueTerminal: return "Flue Terminal"
        case .condensateRoute: return "Condensate Route"
        case .pump: return "Pump"
        case .magneticFilter: return "Magnetic Filter"
        case .otherInfrastructure: return "Other Infrastructure"
        case .unknownInfrastructure: return "Unknown Infrastructure"
        }
    }

    public var legacyKind: SystemComponentKind {
        switch self {
        case .regularBoiler, .systemBoiler, .combiBoiler, .ashp, .otherHeatSource, .unknownHeatSource:
            return .boiler
        case .unventedCylinder, .ventedCylinder, .thermalStore, .coldWaterStorage, .feedAndExpansion, .directCombiDHW, .unknownHotWater:
            return .cylinder
        case .radiatorUncontrolled, .radiatorTRVControlled, .radiatorInRoomStatZone, .radiatorTRVControlledInRoomStatZone, .towelRail, .towelRailTRVControlled, .ufhSingleZone, .ufhZoned, .ufhDedicatedRoomStat, .fanConvector, .unknownEmitter:
            return .radiator
        case .programmer, .roomThermostat, .smartThermostat, .trv, .zoneValve, .weatherCompensation, .unknownControl:
            return .controls
        case .gasMeter:
            return .gasMeter
        case .waterMain, .stopTap, .flueTerminal, .condensateRoute, .magneticFilter, .otherInfrastructure, .unknownInfrastructure:
            return .other
        case .pump:
            return .pump
        }
    }
}

public extension SystemComponentKind {
    var defaultSubtype: SystemComponentSubtype {
        switch self {
        case .boiler: return .unknownHeatSource
        case .flue: return .flueTerminal
        case .controls: return .unknownControl
        case .cylinder: return .unknownHotWater
        case .feedAndExpansion: return .feedAndExpansion
        case .gasMeter: return .gasMeter
        case .radiator: return .radiatorUncontrolled
        case .pump: return .pump
        case .pipework: return .otherInfrastructure
        case .other: return .unknownInfrastructure
        }
    }
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
    static func captureSections(for systemType: HeatingSystemType) -> [CaptureSection] {
        switch systemType {
        case .combi:
            return [
                CaptureSection(kind: .boiler, isRequired: true),
                CaptureSection(kind: .flue, isRequired: true),
                CaptureSection(kind: .controls, isRequired: true),
                CaptureSection(kind: .gasMeter, isRequired: true),
                CaptureSection(kind: .pipework, isRequired: true),
                CaptureSection(kind: .radiator, isRequired: true)
            ]
        case .regularSealed:
            return [
                CaptureSection(kind: .boiler, isRequired: true),
                CaptureSection(kind: .flue, isRequired: true),
                CaptureSection(kind: .controls, isRequired: true),
                CaptureSection(kind: .cylinder, isRequired: true),
                CaptureSection(kind: .gasMeter, isRequired: true),
                CaptureSection(kind: .pipework, isRequired: true),
                CaptureSection(kind: .pump, isRequired: true),
                CaptureSection(kind: .radiator, isRequired: true)
            ]
        case .regularOpenVented:
            return [
                CaptureSection(kind: .boiler, isRequired: true),
                CaptureSection(kind: .flue, isRequired: true),
                CaptureSection(kind: .controls, isRequired: true),
                CaptureSection(kind: .cylinder, isRequired: true),
                CaptureSection(kind: .feedAndExpansion, isRequired: true),
                CaptureSection(kind: .gasMeter, isRequired: true),
                CaptureSection(kind: .pipework, isRequired: true),
                CaptureSection(kind: .pump, isRequired: true),
                CaptureSection(kind: .radiator, isRequired: true)
            ]
        case .unknown:
            return SystemComponentKind.canonicalOrder
                .filter { $0 != .other }
                .map { CaptureSection(kind: $0, isRequired: false) }
        }
    }

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
    public var captureMode: CaptureMode
    public var name: String
    public var manufacturer: String
    public var model: String
    public var notes: String
    public var reviewStatus: ReviewStatus?
    public var reviewNotes: String?
    public var canonicalSubtype: SystemComponentSubtype
    public var componentAttributes: [String: String]
    public var evidence: [Evidence]
    public var spatialPlacement: SpatialPlacement
    public var factState: TwinFactState
    public var spatialContext: SpatialEvidenceContext?

    public var canonicalCategory: SystemComponentCategory {
        canonicalSubtype.category
    }

    public init(
        id: UUID = UUID(),
        kind: SystemComponentKind,
        captureMode: CaptureMode = .create,
        name: String = "",
        manufacturer: String = "",
        model: String = "",
        notes: String = "",
        reviewStatus: ReviewStatus? = nil,
        reviewNotes: String? = nil,
        canonicalSubtype: SystemComponentSubtype? = nil,
        componentAttributes: [String: String] = [:],
        evidence: [Evidence] = [],
        spatialPlacement: SpatialPlacement = SpatialPlacement(),
        factState: TwinFactState = .unknown,
        spatialContext: SpatialEvidenceContext? = nil
    ) {
        self.id = id
        self.kind = kind
        self.captureMode = captureMode
        self.name = name
        self.manufacturer = manufacturer
        self.model = model
        self.notes = notes
        self.reviewStatus = reviewStatus
        self.reviewNotes = reviewNotes
        self.canonicalSubtype = canonicalSubtype ?? kind.defaultSubtype
        self.componentAttributes = componentAttributes
        self.evidence = evidence
        self.spatialPlacement = spatialPlacement
        self.factState = factState
        self.spatialContext = spatialContext
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case captureMode
        case name
        case manufacturer
        case model
        case notes
        case reviewStatus
        case reviewNotes
        case canonicalSubtype
        case componentAttributes
        case evidence
        case spatialPlacement
        case factState
        case spatialContext
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(SystemComponentKind.self, forKey: .kind)
        captureMode = try container.decodeIfPresent(CaptureMode.self, forKey: .captureMode) ?? .create
        name = try container.decode(String.self, forKey: .name)
        manufacturer = try container.decode(String.self, forKey: .manufacturer)
        model = try container.decode(String.self, forKey: .model)
        notes = try container.decode(String.self, forKey: .notes)
        reviewStatus = try container.decodeIfPresent(ReviewStatus.self, forKey: .reviewStatus)
        reviewNotes = try container.decodeIfPresent(String.self, forKey: .reviewNotes)
        canonicalSubtype = try container.decodeIfPresent(SystemComponentSubtype.self, forKey: .canonicalSubtype) ?? kind.defaultSubtype
        componentAttributes = try container.decodeIfPresent([String: String].self, forKey: .componentAttributes) ?? [:]
        evidence = try container.decodeIfPresent([Evidence].self, forKey: .evidence) ?? []
        spatialPlacement = try container.decodeIfPresent(SpatialPlacement.self, forKey: .spatialPlacement) ?? SpatialPlacement()
        factState = try container.decodeIfPresent(TwinFactState.self, forKey: .factState) ?? .unknown
        spatialContext = try container.decodeIfPresent(SpatialEvidenceContext.self, forKey: .spatialContext)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(captureMode, forKey: .captureMode)
        try container.encode(name, forKey: .name)
        try container.encode(manufacturer, forKey: .manufacturer)
        try container.encode(model, forKey: .model)
        try container.encode(notes, forKey: .notes)
        try container.encodeIfPresent(reviewStatus, forKey: .reviewStatus)
        try container.encodeIfPresent(reviewNotes, forKey: .reviewNotes)
        try container.encode(canonicalSubtype, forKey: .canonicalSubtype)
        try container.encode(componentAttributes, forKey: .componentAttributes)
        try container.encode(evidence, forKey: .evidence)
        try container.encode(spatialPlacement, forKey: .spatialPlacement)
        try container.encode(factState, forKey: .factState)
        try container.encodeIfPresent(spatialContext, forKey: .spatialContext)
    }
}

public struct Visit: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var reference: String
    public var createdAt: Date
    public var twinKind: TwinKind
    public var customerName: String
    public var addressLine: String
    public var postcode: String
    public var engineerName: String?
    public var appointmentDate: Date?
    public var notes: String
    public var currentSystemType: HeatingSystemType
    /// Legacy import compatibility only. Capture stores observed systems.
    public var legacySystemType: HeatingSystemType
    public var captureMode: CaptureMode
    public var rooms: [Room]
    public var relationships: [SpatialRelationship]
    public var components: [SystemComponent]
    public var waterSupplyObservations: [WaterSupplyObservation]
    public var servicePointObservations: [ServicePointObservation]
    public var sectionStatuses: [SystemComponentKind: SectionStatus]
    /// Legacy import compatibility only. Capture has one observed section status map.
    public var legacySectionStatuses: [SystemComponentKind: SectionStatus]
    public var repositoryState: TwinRepositoryState
    public var lifecycleStage: TwinLifecycleStage
    public var twinVersion: Int
    public var lastMergedAt: Date?
    public var changeSetCounters: [String: Int]

    public var areas: [Room] {
        get { rooms }
        set { rooms = newValue }
    }

    public init(
        id: UUID = UUID(),
        reference: String,
        createdAt: Date = Date(),
        twinKind: TwinKind,
        customerName: String = "",
        addressLine: String = "",
        postcode: String = "",
        engineerName: String? = nil,
        appointmentDate: Date? = nil,
        notes: String = "",
        currentSystemType: HeatingSystemType = .unknown,
        legacySystemType: HeatingSystemType = .unknown,
        captureMode: CaptureMode = .create,
        rooms: [Room] = [],
        relationships: [SpatialRelationship] = [],
        components: [SystemComponent] = [],
        waterSupplyObservations: [WaterSupplyObservation] = [],
        servicePointObservations: [ServicePointObservation] = [],
        sectionStatuses: [SystemComponentKind: SectionStatus] = [:],
        legacySectionStatuses: [SystemComponentKind: SectionStatus] = [:],
        repositoryState: TwinRepositoryState = .localWorkingCopy,
        lifecycleStage: TwinLifecycleStage = .capture,
        twinVersion: Int = 1,
        lastMergedAt: Date? = nil,
        changeSetCounters: [String: Int] = [:]
    ) {
        self.id = id
        self.reference = reference
        self.createdAt = createdAt
        self.twinKind = twinKind
        self.customerName = customerName
        self.addressLine = addressLine
        self.postcode = postcode
        self.engineerName = engineerName
        self.appointmentDate = appointmentDate
        self.notes = notes
        self.currentSystemType = currentSystemType
        self.legacySystemType = legacySystemType
        self.captureMode = captureMode
        self.rooms = rooms
        self.relationships = relationships
        self.components = components
        self.waterSupplyObservations = waterSupplyObservations
        self.servicePointObservations = servicePointObservations
        self.sectionStatuses = sectionStatuses
        self.legacySectionStatuses = legacySectionStatuses
        self.repositoryState = repositoryState
        self.lifecycleStage = lifecycleStage
        self.twinVersion = max(1, twinVersion)
        self.lastMergedAt = lastMergedAt
        self.changeSetCounters = changeSetCounters
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case reference
        case createdAt
        case twinKind
        case customerName
        case addressLine
        case postcode
        case engineerName
        case appointmentDate
        case notes
        case currentSystemType
        case captureMode
        case rooms
        case relationships
        case components
        case waterSupplyObservations
        case servicePointObservations
        case sectionStatuses
        case repositoryState
        case lifecycleStage
        case twinVersion
        case lastMergedAt
        case changeSetCounters
    }

    private struct LegacyCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            return nil
        }

        static let systemType = LegacyCodingKey(stringValue: "proposed" + "SystemType")!
        static let sectionStatuses = LegacyCodingKey(stringValue: "proposed" + "SectionStatuses")!
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKey.self)
        id = try container.decode(UUID.self, forKey: .id)
        reference = try container.decode(String.self, forKey: .reference)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        twinKind = try container.decode(TwinKind.self, forKey: .twinKind)
        customerName = try container.decodeIfPresent(String.self, forKey: .customerName) ?? ""
        addressLine = try container.decodeIfPresent(String.self, forKey: .addressLine) ?? ""
        postcode = try container.decodeIfPresent(String.self, forKey: .postcode) ?? ""
        engineerName = try container.decodeIfPresent(String.self, forKey: .engineerName)
        appointmentDate = try container.decodeIfPresent(Date.self, forKey: .appointmentDate)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        currentSystemType = try container.decodeIfPresent(HeatingSystemType.self, forKey: .currentSystemType) ?? .unknown
        legacySystemType = try legacyContainer.decodeIfPresent(HeatingSystemType.self, forKey: .systemType) ?? .unknown
        captureMode = try container.decodeIfPresent(CaptureMode.self, forKey: .captureMode) ?? .create
        rooms = try container.decode([Room].self, forKey: .rooms)
        relationships = try container.decodeIfPresent([SpatialRelationship].self, forKey: .relationships) ?? []
        components = try container.decodeIfPresent([SystemComponent].self, forKey: .components) ?? []
        waterSupplyObservations = try container.decodeIfPresent([WaterSupplyObservation].self, forKey: .waterSupplyObservations) ?? []
        servicePointObservations = try container.decodeIfPresent([ServicePointObservation].self, forKey: .servicePointObservations) ?? []
        sectionStatuses = try container.decodeIfPresent([SystemComponentKind: SectionStatus].self, forKey: .sectionStatuses) ?? [:]
        legacySectionStatuses = try legacyContainer.decodeIfPresent([SystemComponentKind: SectionStatus].self, forKey: .sectionStatuses) ?? [:]
        repositoryState = try container.decodeIfPresent(TwinRepositoryState.self, forKey: .repositoryState) ?? .localWorkingCopy
        lifecycleStage = try container.decodeIfPresent(TwinLifecycleStage.self, forKey: .lifecycleStage) ?? .capture
        twinVersion = max(1, try container.decodeIfPresent(Int.self, forKey: .twinVersion) ?? 1)
        lastMergedAt = try container.decodeIfPresent(Date.self, forKey: .lastMergedAt)
        changeSetCounters = try container.decodeIfPresent([String: Int].self, forKey: .changeSetCounters) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(reference, forKey: .reference)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(twinKind, forKey: .twinKind)
        try container.encode(customerName, forKey: .customerName)
        try container.encode(addressLine, forKey: .addressLine)
        try container.encode(postcode, forKey: .postcode)
        try container.encodeIfPresent(engineerName, forKey: .engineerName)
        try container.encodeIfPresent(appointmentDate, forKey: .appointmentDate)
        try container.encode(notes, forKey: .notes)
        try container.encode(currentSystemType, forKey: .currentSystemType)
        try container.encode(captureMode, forKey: .captureMode)
        try container.encode(rooms, forKey: .rooms)
        try container.encode(relationships, forKey: .relationships)
        try container.encode(components, forKey: .components)
        try container.encode(waterSupplyObservations, forKey: .waterSupplyObservations)
        try container.encode(servicePointObservations, forKey: .servicePointObservations)
        try container.encode(sectionStatuses, forKey: .sectionStatuses)
        try container.encode(repositoryState, forKey: .repositoryState)
        try container.encode(lifecycleStage, forKey: .lifecycleStage)
        try container.encode(twinVersion, forKey: .twinVersion)
        try container.encodeIfPresent(lastMergedAt, forKey: .lastMergedAt)
        try container.encode(changeSetCounters, forKey: .changeSetCounters)
    }
}

public struct CaptureSection: Hashable, Sendable {
    public let kind: SystemComponentKind
    public let isRequired: Bool

    public init(kind: SystemComponentKind, isRequired: Bool) {
        self.kind = kind
        self.isRequired = isRequired
    }
}

public struct VisitPackage: Codable, Hashable, Sendable {
    public var metadata: VisitPackageMetadata?
    public var schemaVersion: Int
    public var exportedAt: Date
    public var visits: [Visit]

    public init(
        metadata: VisitPackageMetadata? = nil,
        schemaVersion: Int = VisitPackageMetadata.currentSchemaVersion,
        exportedAt: Date = Date(),
        visits: [Visit]
    ) {
        let resolvedMetadata = metadata ?? VisitPackageMetadata(
            schemaVersion: schemaVersion,
            createdAt: exportedAt
        )
        self.metadata = resolvedMetadata
        self.schemaVersion = resolvedMetadata.schemaVersion
        self.exportedAt = resolvedMetadata.createdAt
        self.visits = visits
    }

    private enum CodingKeys: String, CodingKey {
        case metadata
        case schemaVersion
        case exportedAt
        case visits
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        visits = try container.decode([Visit].self, forKey: .visits)

        if let metadata = try container.decodeIfPresent(VisitPackageMetadata.self, forKey: .metadata) {
            self.metadata = metadata
            schemaVersion = metadata.schemaVersion
            exportedAt = metadata.createdAt
            return
        }

        self.metadata = nil
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? VisitPackageMetadata.currentSchemaVersion
        exportedAt = try container.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Date(timeIntervalSince1970: 0)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let metadataToEncode = metadata ?? VisitPackageMetadata(
            schemaVersion: schemaVersion,
            createdAt: exportedAt
        )
        try container.encode(metadataToEncode, forKey: .metadata)
        try container.encode(metadataToEncode.schemaVersion, forKey: .schemaVersion)
        try container.encode(metadataToEncode.createdAt, forKey: .exportedAt)
        try container.encode(visits, forKey: .visits)
    }
}

public struct VisitPackageMetadata: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 3
    public static let canonicalSource = "Daedalus Capture"

    public var packageID: UUID
    public var schemaVersion: Int
    public var createdAt: Date
    public var exportedByApp: String
    public var appVersion: String?
    public var source: String

    public init(
        packageID: UUID = UUID(),
        schemaVersion: Int = currentSchemaVersion,
        createdAt: Date = Date(),
        exportedByApp: String = canonicalSource,
        appVersion: String? = nil,
        source: String = canonicalSource
    ) {
        self.packageID = packageID
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.exportedByApp = exportedByApp
        self.appVersion = appVersion
        self.source = source
    }
}

public enum DaedalusCatalog {
    public static let defaultSurvey: [SurveyQuestion] = []
}
