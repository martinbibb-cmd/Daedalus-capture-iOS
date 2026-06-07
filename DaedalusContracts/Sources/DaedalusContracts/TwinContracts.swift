import Foundation

public enum Confidence: String, Codable, CaseIterable, Sendable {
    case observed
    case approximate
    case unknown
    case unresolved
}

public struct TwinProvenance: Codable, Hashable, Sendable {
    public var source: String
    public var observedAt: Date?
    public var observedBy: String?
    public var notes: String?

    public init(
        source: String,
        observedAt: Date? = nil,
        observedBy: String? = nil,
        notes: String? = nil
    ) {
        self.source = source
        self.observedAt = observedAt
        self.observedBy = observedBy
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case source = "method"
        case observedAt = "captured_at"
        case observedBy = "captured_by"
        case notes
    }
}

public struct TwinEvidence: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var description: String?
    public var provenance: TwinProvenance
    public var confidence: Confidence

    public init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        provenance: TwinProvenance,
        confidence: Confidence
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.provenance = provenance
        self.confidence = confidence
    }
}

public enum CaptureState: String, Codable, CaseIterable, Sendable {
    case anchored
    case approximate
    case roomAttached
    case evidenceOnly
    case unresolved
}

public struct TwinSpatialPlacement: Codable, Hashable, Sendable {
    public var anchorID: String?
    public var confidence: Confidence
    public var captureState: CaptureState
    public var approximatePosition: SpatialPosition?

    public init(
        anchorID: String? = nil,
        confidence: Confidence,
        captureState: CaptureState,
        approximatePosition: SpatialPosition? = nil
    ) {
        self.anchorID = anchorID
        self.confidence = confidence
        self.captureState = captureState
        self.approximatePosition = approximatePosition
    }
}

public struct SpatialArea: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var placement: TwinSpatialPlacement
    public var confidence: Confidence

    public init(
        id: UUID = UUID(),
        name: String,
        placement: TwinSpatialPlacement,
        confidence: Confidence
    ) {
        self.id = id
        self.name = name
        self.placement = placement
        self.confidence = confidence
    }
}

public struct HouseTwin: Codable, Hashable, Sendable {
    public let id: UUID
    public var areas: [SpatialArea]

    public init(id: UUID = UUID(), areas: [SpatialArea]) {
        self.id = id
        self.areas = areas
    }
}

public enum SystemAssetType: String, Codable, CaseIterable, Sendable {
    case boiler
    case cylinder
    case thermalStore
    case radiator
    case control
    case pump
    case valve
    case flue
    case meter
    case unknown
}

public struct SystemAsset: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var assetType: SystemAssetType
    public var canonicalCategory: String
    public var canonicalSubtype: String
    public var placement: TwinSpatialPlacement
    public var confidence: Confidence
    public var evidenceIDs: [UUID]

    public init(
        id: UUID = UUID(),
        assetType: SystemAssetType,
        canonicalCategory: String = SystemComponentCategory.unknown.rawValue,
        canonicalSubtype: String = SystemComponentSubtype.unknownInfrastructure.rawValue,
        placement: TwinSpatialPlacement,
        confidence: Confidence,
        evidenceIDs: [UUID]
    ) {
        self.id = id
        self.assetType = assetType
        self.canonicalCategory = canonicalCategory
        self.canonicalSubtype = canonicalSubtype
        self.placement = placement
        self.confidence = confidence
        self.evidenceIDs = evidenceIDs
    }
}

public struct SystemRelationship: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var sourceAssetID: UUID
    public var relationship: SpatialRelationshipType
    public var targetAssetID: UUID?
    public var targetAreaID: UUID?

    public init(
        id: UUID = UUID(),
        sourceAssetID: UUID,
        relationship: SpatialRelationshipType,
        targetAssetID: UUID? = nil,
        targetAreaID: UUID? = nil
    ) {
        self.id = id
        self.sourceAssetID = sourceAssetID
        self.relationship = relationship
        self.targetAssetID = targetAssetID
        self.targetAreaID = targetAreaID
    }
}

public struct SystemTwin: Codable, Hashable, Sendable {
    public let id: UUID
    public var assets: [SystemAsset]
    public var relationships: [SystemRelationship]

    public init(id: UUID = UUID(), assets: [SystemAsset], relationships: [SystemRelationship] = []) {
        self.id = id
        self.assets = assets
        self.relationships = relationships
    }
}

public struct HomeTwin: Codable, Hashable, Sendable {
    public let id: UUID
    public var occupancyDescription: String?
    public var notes: String?

    public init(
        id: UUID = UUID(),
        occupancyDescription: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.occupancyDescription = occupancyDescription
        self.notes = notes
    }
}

public struct UnifiedPropertyTwin: Codable, Hashable, Sendable {
    public var house: HouseTwin
    public var system: SystemTwin
    public var home: HomeTwin

    public init(house: HouseTwin, system: SystemTwin, home: HomeTwin) {
        self.house = house
        self.system = system
        self.home = home
    }
}

public struct DaedalusPackage: Codable, Hashable, Sendable {
    public static let currentPackageVersion = 3

    public var packageVersion: Int
    public var packageID: UUID
    public var visitID: UUID
    public var propertyRef: String
    public var createdAt: Date
    public var observations: [DaedalusObservation]
    public var relationships: [DaedalusRelationship]
    public var waterSupplyObservations: [WaterSupplyObservation]
    public var servicePointObservations: [ServicePointObservation]

    public init(
        packageVersion: Int = currentPackageVersion,
        packageID: UUID = UUID(),
        visitID: UUID,
        propertyRef: String,
        createdAt: Date = Date(),
        observations: [DaedalusObservation],
        relationships: [DaedalusRelationship] = [],
        waterSupplyObservations: [WaterSupplyObservation] = [],
        servicePointObservations: [ServicePointObservation] = []
    ) {
        self.packageVersion = packageVersion
        self.packageID = packageID
        self.visitID = visitID
        self.propertyRef = propertyRef
        self.createdAt = createdAt
        self.observations = observations
        self.relationships = relationships
        self.waterSupplyObservations = waterSupplyObservations
        self.servicePointObservations = servicePointObservations
    }

    enum CodingKeys: String, CodingKey {
        case packageVersion
        case packageID = "packageId"
        case visitID = "visitId"
        case propertyRef
        case createdAt = "captured_at"
        case observations
        case relationships
        case waterSupplyObservations
        case servicePointObservations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        packageVersion = try container.decode(Int.self, forKey: .packageVersion)
        packageID = try container.decode(UUID.self, forKey: .packageID)
        visitID = try container.decode(UUID.self, forKey: .visitID)
        propertyRef = try container.decode(String.self, forKey: .propertyRef)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        observations = try container.decode([DaedalusObservation].self, forKey: .observations)
        relationships = try container.decodeIfPresent([DaedalusRelationship].self, forKey: .relationships) ?? []
        waterSupplyObservations = try container.decodeIfPresent([WaterSupplyObservation].self, forKey: .waterSupplyObservations) ?? []
        servicePointObservations = try container.decodeIfPresent([ServicePointObservation].self, forKey: .servicePointObservations) ?? []
    }
}

public enum WaterSupplyMethod: String, Codable, CaseIterable, Identifiable, Sendable {
    case digitalPressureFlowLogger
    case pressureFlowTestKit
    case flowCup
    case pressureGauge
    case customerReported
    case notTested
    case other
    case unknown

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .digitalPressureFlowLogger: return "Digital logger"
        case .pressureFlowTestKit: return "Pressure + flow kit"
        case .flowCup: return "Flow cup"
        case .pressureGauge: return "Pressure gauge"
        case .customerReported: return "Customer reported"
        case .notTested: return "Not tested"
        case .other: return "Other"
        case .unknown: return "Unknown"
        }
    }

    public var qualityHint: String {
        switch self {
        case .digitalPressureFlowLogger: return "Best evidence"
        case .pressureFlowTestKit: return "Good evidence"
        case .flowCup: return "Useful but local only"
        case .pressureGauge: return "Pressure-only evidence"
        case .customerReported: return "Context only"
        case .notTested: return "Valid absence"
        case .other, .unknown: return "Record what was observed"
        }
    }
}

public enum WaterSupplyLocation: String, Codable, CaseIterable, Identifiable, Sendable {
    case outsideTap
    case kitchenColdTap
    case internalStopTap
    case washingMachineValve
    case bathroomBasinTap
    case bathTap
    case showerOutlet
    case cylinderCupboard
    case cylinderColdInlet
    case loftTankFeed
    case waterMain
    case other
    case unknown

    public var id: String { rawValue }
}

public enum WaterSupplyIntent: String, Codable, CaseIterable, Identifiable, Sendable {
    case incomingMainCapacity
    case usableHouseholdCapacity
    case hotWaterPlantFeed
    case servicePointExperience
    case customerComplaintContext
    case notTested
    case unknown

    public var id: String { rawValue }
}

public enum WaterMeasurementValueName: String, Codable, CaseIterable, Identifiable, Sendable {
    case staticPressure
    case dynamicPressure
    case residualPressure
    case flowRate
    case flowAtPressure
    case waterTemperature
    case tds
    case qualitativeObservation

    public var id: String { rawValue }
}

public enum WaterBoundaryState: String, Codable, CaseIterable, Identifiable, Sendable {
    case `true`
    case `false`
    case unknown

    public var id: String { rawValue }
}

public enum WaterSuspectedLimitation: String, Codable, CaseIterable, Identifiable, Sendable {
    case restrictedOutlet
    case aerator
    case monoblocTails
    case isolationValvePartClosed
    case seizedStopTap
    case inaccessibleMain
    case prvSuspected
    case softenerOrFilter
    case sharedSupplySuspected
    case customerReportOnly
    case noSuitableOutlet
    case other

    public var id: String { rawValue }
}

public enum WaterAbsenceReason: String, Codable, CaseIterable, Identifiable, Sendable {
    case notSafe
    case noAccess
    case seizedValve
    case noSuitableOutlet
    case customerDeclined
    case timeConstraint
    case equipmentUnavailable
    case other

    public var id: String { rawValue }
}

public struct WaterMeasurementValue: Codable, Hashable, Identifiable, Sendable {
    public var id: String { "\(name.rawValue):\(condition ?? "")" }
    public var name: WaterMeasurementValueName
    public var value: String
    public var unit: String?
    public var condition: String?
    public var confidence: Confidence?

    enum CodingKeys: String, CodingKey {
        case name
        case value
        case unit
        case condition
        case confidence
    }

    public init(
        name: WaterMeasurementValueName,
        value: String,
        unit: String? = nil,
        condition: String? = nil,
        confidence: Confidence? = nil
    ) {
        self.name = name
        self.value = value
        self.unit = unit
        self.condition = condition
        self.confidence = confidence
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(WaterMeasurementValueName.self, forKey: .name)
        if let stringValue = try? container.decode(String.self, forKey: .value) {
            value = stringValue
        } else if let doubleValue = try? container.decode(Double.self, forKey: .value) {
            if doubleValue.rounded() == doubleValue {
                value = String(Int(doubleValue))
            } else {
                value = String(doubleValue)
            }
        } else {
            value = try String(container.decode(Int.self, forKey: .value))
        }
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
        condition = try container.decodeIfPresent(String.self, forKey: .condition)
        confidence = try container.decodeIfPresent(Confidence.self, forKey: .confidence)
    }
}

public struct WaterBoundaryConditions: Codable, Hashable, Sendable {
    public var mainsStopTapFullyOpen: WaterBoundaryState
    public var visiblePrvFitted: WaterBoundaryState
    public var softenerOrFilterPresent: WaterBoundaryState
    public var otherOutletsOpenDuringTest: WaterBoundaryState
    public var restrictorOrAeratorSuspected: WaterBoundaryState
    public var timeOfDay: String?
    public var notes: String?

    public init(
        mainsStopTapFullyOpen: WaterBoundaryState = .unknown,
        visiblePrvFitted: WaterBoundaryState = .unknown,
        softenerOrFilterPresent: WaterBoundaryState = .unknown,
        otherOutletsOpenDuringTest: WaterBoundaryState = .unknown,
        restrictorOrAeratorSuspected: WaterBoundaryState = .unknown,
        timeOfDay: String? = nil,
        notes: String? = nil
    ) {
        self.mainsStopTapFullyOpen = mainsStopTapFullyOpen
        self.visiblePrvFitted = visiblePrvFitted
        self.softenerOrFilterPresent = softenerOrFilterPresent
        self.otherOutletsOpenDuringTest = otherOutletsOpenDuringTest
        self.restrictorOrAeratorSuspected = restrictorOrAeratorSuspected
        self.timeOfDay = timeOfDay
        self.notes = notes
    }
}

public struct WaterSupplyObservation: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var observedAt: Date
    public var observedBy: String
    public var method: WaterSupplyMethod
    public var location: WaterSupplyLocation
    public var intent: WaterSupplyIntent
    public var instrument: String?
    public var values: [WaterMeasurementValue]
    public var boundaryConditions: WaterBoundaryConditions
    public var suspectedLimitations: [WaterSuspectedLimitation]
    public var absenceReason: WaterAbsenceReason?
    public var confidence: Confidence
    public var evidenceIDs: [String]
    public var provenance: TwinProvenance
    public var notes: String?

    public init(
        id: String = UUID().uuidString,
        observedAt: Date = Date(),
        observedBy: String,
        method: WaterSupplyMethod,
        location: WaterSupplyLocation,
        intent: WaterSupplyIntent,
        instrument: String? = nil,
        values: [WaterMeasurementValue] = [],
        boundaryConditions: WaterBoundaryConditions = WaterBoundaryConditions(),
        suspectedLimitations: [WaterSuspectedLimitation] = [],
        absenceReason: WaterAbsenceReason? = nil,
        confidence: Confidence,
        evidenceIDs: [String] = [],
        provenance: TwinProvenance,
        notes: String? = nil
    ) {
        self.id = id
        self.observedAt = observedAt
        self.observedBy = observedBy
        self.method = method
        self.location = location
        self.intent = intent
        self.instrument = instrument
        self.values = values
        self.boundaryConditions = boundaryConditions
        self.suspectedLimitations = suspectedLimitations
        self.absenceReason = absenceReason
        self.confidence = confidence
        self.evidenceIDs = evidenceIDs
        self.provenance = provenance
        self.notes = notes
    }
}

public enum ServicePointType: String, Codable, CaseIterable, Identifiable, Sendable {
    case kitchenTap
    case bathTap
    case basinTap
    case showerMixer
    case electricShower
    case outsideTap
    case washingMachineValve
    case cylinderInlet
    case other
    case unknown

    public var id: String { rawValue }
}

public enum SupplyType: String, Codable, CaseIterable, Identifiable, Sendable {
    case mainsCold
    case storedCold
    case gravityHot
    case mainsHot
    case pumpedHot
    case mixed
    case unknown

    public var id: String { rawValue }
}

public enum IntendedPressureType: String, Codable, CaseIterable, Identifiable, Sendable {
    case mainsPressure
    case gravityLowPressure
    case pumped
    case universal
    case unknown

    public var id: String { rawValue }
}

public enum ObservedIssue: String, Codable, CaseIterable, Identifiable, Sendable {
    case poorFlow
    case temperatureFluctuation
    case slowBathFill
    case noisyOperation
    case outletRestrictionSuspected
    case mismatchSuspected
    case scaledOrRestricted
    case noIssueObserved
    case unknown

    public var id: String { rawValue }
}

public struct ServicePointObservation: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var areaID: String
    public var servicePointType: ServicePointType
    public var supplyType: SupplyType
    public var intendedPressureType: IntendedPressureType
    public var servedByAssetIDs: [String]
    public var observedIssues: [ObservedIssue]
    public var evidenceIDs: [String]
    public var confidence: Confidence
    public var provenance: TwinProvenance
    public var notes: String?

    public init(
        id: String = UUID().uuidString,
        areaID: String,
        servicePointType: ServicePointType,
        supplyType: SupplyType = .unknown,
        intendedPressureType: IntendedPressureType = .unknown,
        servedByAssetIDs: [String] = [],
        observedIssues: [ObservedIssue] = [],
        evidenceIDs: [String] = [],
        confidence: Confidence,
        provenance: TwinProvenance,
        notes: String? = nil
    ) {
        self.id = id
        self.areaID = areaID
        self.servicePointType = servicePointType
        self.supplyType = supplyType
        self.intendedPressureType = intendedPressureType
        self.servedByAssetIDs = servedByAssetIDs
        self.observedIssues = observedIssues
        self.evidenceIDs = evidenceIDs
        self.confidence = confidence
        self.provenance = provenance
        self.notes = notes
    }
}

public struct DaedalusObservation: Codable, Hashable, Identifiable, Sendable {
    public var observationID: String
    public var tag: String
    public var name: String?
    public var type: String?
    public var manufacturer: String?
    public var model: String?
    public var notes: String?
    public var roomRef: String?
    public var assetRef: String?
    public var fileRef: String?
    public var confidence: Confidence?
    public var captureState: CaptureState?
    public var position: SpatialPosition?
    public var evidenceRefs: [String]
    public var provenance: TwinProvenance

    public var id: String { observationID }

    public init(
        observationID: String,
        tag: String,
        name: String? = nil,
        type: String? = nil,
        manufacturer: String? = nil,
        model: String? = nil,
        notes: String? = nil,
        roomRef: String? = nil,
        assetRef: String? = nil,
        fileRef: String? = nil,
        confidence: Confidence? = nil,
        captureState: CaptureState? = nil,
        position: SpatialPosition? = nil,
        evidenceRefs: [String] = [],
        provenance: TwinProvenance
    ) {
        self.observationID = observationID
        self.tag = tag
        self.name = name
        self.type = type
        self.manufacturer = manufacturer
        self.model = model
        self.notes = notes
        self.roomRef = roomRef
        self.assetRef = assetRef
        self.fileRef = fileRef
        self.confidence = confidence
        self.captureState = captureState
        self.position = position
        self.evidenceRefs = evidenceRefs
        self.provenance = provenance
    }

    enum CodingKeys: String, CodingKey {
        case observationID = "observation_id"
        case tag
        case name
        case type
        case manufacturer
        case model
        case notes
        case roomRef = "room_ref"
        case assetRef = "asset_ref"
        case fileRef = "file_ref"
        case confidence
        case captureState = "capture_state"
        case position
        case evidenceRefs = "evidence_refs"
        case provenance
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        observationID = try container.decode(String.self, forKey: .observationID)
        tag = try container.decode(String.self, forKey: .tag)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        manufacturer = try container.decodeIfPresent(String.self, forKey: .manufacturer)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        roomRef = try container.decodeIfPresent(String.self, forKey: .roomRef)
        assetRef = try container.decodeIfPresent(String.self, forKey: .assetRef)
        fileRef = try container.decodeIfPresent(String.self, forKey: .fileRef)
        confidence = try container.decodeIfPresent(Confidence.self, forKey: .confidence)
        captureState = try container.decodeIfPresent(CaptureState.self, forKey: .captureState)
        position = try container.decodeIfPresent(SpatialPosition.self, forKey: .position)
        evidenceRefs = try container.decodeIfPresent([String].self, forKey: .evidenceRefs) ?? []
        provenance = try container.decode(TwinProvenance.self, forKey: .provenance)
    }
}

public struct DaedalusRelationship: Codable, Hashable, Identifiable, Sendable {
    public var relationshipID: String
    public var type: SpatialRelationshipType
    public var from: String
    public var to: String
    public var evidenceRefs: [String]
    public var provenance: TwinProvenance

    public var id: String { relationshipID }

    public init(
        relationshipID: String,
        type: SpatialRelationshipType,
        from: String,
        to: String,
        evidenceRefs: [String] = [],
        provenance: TwinProvenance
    ) {
        self.relationshipID = relationshipID
        self.type = type
        self.from = from
        self.to = to
        self.evidenceRefs = evidenceRefs
        self.provenance = provenance
    }

    enum CodingKeys: String, CodingKey {
        case relationshipID = "relationship_id"
        case type
        case from
        case to
        case evidenceRefs = "evidence_refs"
        case provenance
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        relationshipID = try container.decode(String.self, forKey: .relationshipID)
        type = try container.decode(SpatialRelationshipType.self, forKey: .type)
        from = try container.decode(String.self, forKey: .from)
        to = try container.decode(String.self, forKey: .to)
        evidenceRefs = try container.decodeIfPresent([String].self, forKey: .evidenceRefs) ?? []
        provenance = try container.decode(TwinProvenance.self, forKey: .provenance)
    }
}

public struct PackageValidationIssue: Hashable, Sendable {
    public enum Severity: String, Codable, Hashable, Sendable {
        case error
        case warning
    }

    public var path: String
    public var code: String
    public var message: String
    public var severity: Severity

    public init(
        path: String,
        code: String,
        message: String,
        severity: Severity = .error
    ) {
        self.path = path
        self.code = code
        self.message = message
        self.severity = severity
    }
}

public struct PackageValidationResult: Hashable, Sendable {
    public var valid: Bool
    public var issues: [PackageValidationIssue]

    public init(valid: Bool, issues: [PackageValidationIssue]) {
        self.valid = valid
        self.issues = issues
    }
}

public func validateEvidenceReferences(_ packageData: DaedalusPackage) -> [PackageValidationIssue] {
    let observationIDs = Set(packageData.observations.map(\.observationID))
    var issues: [PackageValidationIssue] = []

    for (observationIndex, observation) in packageData.observations.enumerated() {
        for (evidenceIndex, evidenceRef) in observation.evidenceRefs.enumerated() where !observationIDs.contains(evidenceRef) {
            issues.append(
                PackageValidationIssue(
                    path: "observations[\(observationIndex)].evidenceRefs[\(evidenceIndex)]",
                    code: "evidence.reference.missing",
                    message: "Evidence reference does not exist in package observations array: \(evidenceRef)"
                )
            )
        }
    }

    return issues
}

public func validateTwinIntegrity(_ packageData: DaedalusPackage) -> [PackageValidationIssue] {
    var issues: [PackageValidationIssue] = []
    issues.append(
        contentsOf: duplicateIDIssues(
            ids: packageData.observations.map(\.observationID),
            pathPrefix: "observations",
            code: "observation.id.duplicate",
            message: "Duplicate observation_id"
        )
    )
    let observationIDs = Set(packageData.observations.map(\.observationID))
    for (relationshipIndex, relationship) in packageData.relationships.enumerated() {
        if !observationIDs.contains(relationship.from) {
            issues.append(
                PackageValidationIssue(
                    path: "relationships[\(relationshipIndex)].from",
                    code: "relationship.endpoint.missing",
                    message: "Relationship source does not exist in package observations array: \(relationship.from)"
                )
            )
        }
        if !observationIDs.contains(relationship.to) {
            issues.append(
                PackageValidationIssue(
                    path: "relationships[\(relationshipIndex)].to",
                    code: "relationship.endpoint.missing",
                    message: "Relationship target does not exist in package observations array: \(relationship.to)"
                )
            )
        }
    }
    issues.append(
        contentsOf: duplicateIDIssues(
            ids: packageData.waterSupplyObservations.map(\.id),
            pathPrefix: "waterSupplyObservations",
            code: "waterSupplyObservation.id.duplicate",
            message: "Duplicate water supply observation id"
        )
    )
    issues.append(
        contentsOf: duplicateIDIssues(
            ids: packageData.servicePointObservations.map(\.id),
            pathPrefix: "servicePointObservations",
            code: "servicePointObservation.id.duplicate",
            message: "Duplicate service point observation id"
        )
    )
    let evidenceObservationIDs = Set(
        packageData.observations
            .filter { $0.tag.localizedCaseInsensitiveContains("evidence") }
            .map(\.observationID)
    )
    let areaObservationIDs = Set(
        packageData.observations
            .filter { $0.tag.localizedCaseInsensitiveCompare("area") == .orderedSame }
            .map(\.observationID)
    )
    for (observationIndex, observation) in packageData.waterSupplyObservations.enumerated() {
        if observation.method == .notTested,
           observation.absenceReason == nil,
           observation.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            issues.append(
                PackageValidationIssue(
                    path: "waterSupplyObservations[\(observationIndex)].absenceReason",
                    code: "waterSupply.notTested.reasonMissing",
                    message: "Not tested water observations require an absence reason or notes."
                )
            )
        }
        if observation.method == .customerReported,
           observation.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false,
           !observation.values.contains(where: { $0.name == .qualitativeObservation }) {
            issues.append(
                PackageValidationIssue(
                    path: "waterSupplyObservations[\(observationIndex)].values",
                    code: "waterSupply.customerReported.contextMissing",
                    message: "Customer reported water observations require a qualitative observation or notes."
                )
            )
        }
        for (valueIndex, value) in observation.values.enumerated()
            where Double(value.value) != nil && value.unit?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            issues.append(
                PackageValidationIssue(
                    path: "waterSupplyObservations[\(observationIndex)].values[\(valueIndex)].unit",
                    code: "waterSupply.value.unitMissing",
                    message: "Numeric water measurement values require a unit."
                )
            )
        }
        for (evidenceIndex, evidenceID) in observation.evidenceIDs.enumerated()
            where !evidenceObservationIDs.contains(evidenceID) {
            issues.append(
                PackageValidationIssue(
                    path: "waterSupplyObservations[\(observationIndex)].evidenceIDs[\(evidenceIndex)]",
                    code: "waterSupply.evidence.reference.missing",
                    message: "Water supply evidence reference does not exist in package observations array: \(evidenceID)"
                )
            )
        }
    }
    for (observationIndex, observation) in packageData.servicePointObservations.enumerated() {
        if !areaObservationIDs.contains(observation.areaID) {
            issues.append(
                PackageValidationIssue(
                    path: "servicePointObservations[\(observationIndex)].areaID",
                    code: "servicePoint.area.reference.missing",
                    message: "Service point area reference does not exist in package area observations: \(observation.areaID)"
                )
            )
        }
        for (assetIndex, assetID) in observation.servedByAssetIDs.enumerated()
            where !observationIDs.contains(assetID) {
            issues.append(
                PackageValidationIssue(
                    path: "servicePointObservations[\(observationIndex)].servedByAssetIDs[\(assetIndex)]",
                    code: "servicePoint.servedByAsset.reference.missing",
                    message: "Service point served asset reference does not exist in package observations array: \(assetID)"
                )
            )
        }
        for (evidenceIndex, evidenceID) in observation.evidenceIDs.enumerated()
            where !evidenceObservationIDs.contains(evidenceID) {
            issues.append(
                PackageValidationIssue(
                    path: "servicePointObservations[\(observationIndex)].evidenceIDs[\(evidenceIndex)]",
                    code: "servicePoint.evidence.reference.missing",
                    message: "Service point evidence reference does not exist in package observations array: \(evidenceID)"
                )
            )
        }
    }
    return issues
}

public func validateDaedalusPackage(_ packageData: DaedalusPackage) -> PackageValidationResult {
    let issues = validateEvidenceReferences(packageData) + validateTwinIntegrity(packageData)
    return PackageValidationResult(valid: issues.isEmpty, issues: issues)
}

public enum DaedalusPackageExporter {
    public static func makePackage(
        from visit: Visit,
        packageID: UUID = UUID(),
        createdAt: Date = Date(),
        source: String = VisitPackageMetadata.canonicalSource
    ) -> DaedalusPackage {
        return DaedalusPackage(
            packageID: packageID,
            visitID: visit.id,
            propertyRef: visit.reference,
            createdAt: createdAt,
            observations: observations(from: visit, source: source),
            relationships: visit.relationships.compactMap { $0.exportedDaedalusRelationship(source: source, visit: visit) },
            waterSupplyObservations: visit.waterSupplyObservations.map { $0.exportedDaedalusWaterObservation(source: source, visit: visit) },
            servicePointObservations: visit.servicePointObservations.map { $0.exportedDaedalusServicePointObservation(source: source, visit: visit) }
        )
    }

    private static func observations(from visit: Visit, source: String) -> [DaedalusObservation] {
        let areaObservations = visit.rooms.map { $0.exportedDaedalusObservation(source: source, visit: visit) }
        let assetObservations = visit.components.map { $0.exportedDaedalusObservation(source: source, visit: visit) }
        let roomEvidence = visit.rooms.flatMap { room in
            room.evidence.map { $0.exportedDaedalusEvidence(source: source, visit: visit, assetRef: room.id.uuidString) }
        }
        let componentEvidence = visit.components.flatMap { component in
            component.evidence.map { $0.exportedDaedalusEvidence(source: source, visit: visit, assetRef: component.id.uuidString) }
        }
        let homeObservation = visit.exportedHomeObservation(source: source)
        return areaObservations + assetObservations + roomEvidence + componentEvidence + [homeObservation].compactMap { $0 }
    }
}

private func duplicateIDIssues(
    ids: [String],
    pathPrefix: String,
    code: String,
    message: String
) -> [PackageValidationIssue] {
    var seen = Set<String>()
    var issues: [PackageValidationIssue] = []

    for (index, id) in ids.enumerated() {
        if seen.contains(id) {
            issues.append(
                PackageValidationIssue(
                    path: "\(pathPrefix)[\(index)].id",
                    code: code,
                    message: "\(message): \(id)"
                )
            )
        } else {
            seen.insert(id)
        }
    }

    return issues
}

private extension Room {
    func exportedDaedalusObservation(source: String, visit: Visit) -> DaedalusObservation {
        DaedalusObservation(
            observationID: id.uuidString,
            tag: "area",
            name: name,
            notes: notes.nilIfEmpty,
            confidence: exportedSpatialArea.confidence,
            captureState: exportedSpatialArea.placement.captureState,
            position: spatialPlacement.approximatePosition,
            evidenceRefs: evidence.map { $0.id.uuidString },
            provenance: TwinProvenance(
                source: source,
                observedAt: visit.createdAt,
                observedBy: visit.exportedObserver(source: source),
                notes: reviewNotes
            )
        )
    }

    var exportedSpatialArea: SpatialArea {
        let anchored = spatialPlacement.captureState == .anchored && spatialPlacement.anchorID?.isEmpty == false
        let confidence: Confidence = anchored ? spatialPlacement.confidence.exportedConfidence : .approximate
        let placement = TwinSpatialPlacement(
            anchorID: anchored ? spatialPlacement.anchorID : nil,
            confidence: confidence,
            captureState: anchored ? .anchored : .approximate,
            approximatePosition: spatialPlacement.approximatePosition
        )
        return SpatialArea(
            id: id,
            name: name,
            placement: placement,
            confidence: confidence
        )
    }
}

private extension SystemComponent {
    func exportedDaedalusObservation(source: String, visit: Visit) -> DaedalusObservation {
        let asset = exportedSystemAsset
        return DaedalusObservation(
            observationID: id.uuidString,
            tag: kind.exportedObservationTag,
            name: exportedContextTitle,
            type: canonicalSubtype.rawValue,
            manufacturer: manufacturer.nilIfEmpty,
            model: model.nilIfEmpty,
            notes: notes.nilIfEmpty,
            roomRef: componentAttributes["location"].nilIfEmpty,
            confidence: asset.confidence,
            captureState: asset.placement.captureState,
            position: spatialPlacement.approximatePosition,
            evidenceRefs: evidence.map { $0.id.uuidString },
            provenance: TwinProvenance(
                source: source,
                observedAt: visit.createdAt,
                observedBy: visit.exportedObserver(source: source),
                notes: reviewNotes
            )
        )
    }

    var exportedSystemAsset: SystemAsset {
        let hasRoomAssociation = !(componentAttributes["location"]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasEvidence = !evidence.isEmpty
        let mappedState: CaptureState

        switch spatialPlacement.captureState {
        case .anchored where spatialPlacement.anchorID?.isEmpty == false:
            mappedState = .anchored
        case .approximate:
            mappedState = .approximate
        case .areaReferenceOnly:
            mappedState = .roomAttached
        case .failed, .unspecified:
            mappedState = hasRoomAssociation ? .roomAttached : .evidenceOnly
        default:
            mappedState = .evidenceOnly
        }

        let confidence = exportedConfidence(
            for: mappedState,
            hasEvidence: hasEvidence,
            hasRoomAssociation: hasRoomAssociation
        )
        let placement = TwinSpatialPlacement(
            anchorID: mappedState == .anchored ? spatialPlacement.anchorID : nil,
            confidence: confidence,
            captureState: mappedState,
            approximatePosition: spatialPlacement.approximatePosition
        )

        return SystemAsset(
            id: id,
            assetType: kind.exportedAssetType,
            canonicalCategory: canonicalCategory.rawValue,
            canonicalSubtype: canonicalSubtype.rawValue,
            placement: placement,
            confidence: confidence,
            evidenceIDs: evidence.map(\.id)
        )
    }

    var exportedContextTitle: String {
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        return kind.title
    }

    private func exportedConfidence(
        for state: CaptureState,
        hasEvidence: Bool,
        hasRoomAssociation: Bool
    ) -> Confidence {
        switch state {
        case .anchored:
            return spatialPlacement.confidence.exportedConfidence
        case .approximate, .roomAttached:
            let mapped = spatialPlacement.confidence.exportedConfidence
            return mapped == .unknown ? .approximate : mapped
        case .evidenceOnly:
            return hasEvidence ? .observed : (hasRoomAssociation ? .approximate : .unknown)
        case .unresolved:
            return .unresolved
        }
    }
}

private extension SpatialRelationship {
    func exportedDaedalusRelationship(source: String, visit: Visit) -> DaedalusRelationship? {
        guard let targetID = targetComponentID ?? targetAreaID else {
            return nil
        }

        return DaedalusRelationship(
            relationshipID: id.uuidString,
            type: relationship,
            from: sourceComponentID.uuidString,
            to: targetID.uuidString,
            provenance: TwinProvenance(
                source: source,
                observedAt: visit.createdAt,
                observedBy: visit.exportedObserver(source: source)
            )
        )
    }
}

private extension WaterSupplyObservation {
    func exportedDaedalusWaterObservation(source: String, visit: Visit) -> WaterSupplyObservation {
        WaterSupplyObservation(
            id: id,
            observedAt: observedAt,
            observedBy: observedBy.nilIfEmpty ?? visit.exportedObserver(source: source),
            method: method,
            location: location,
            intent: intent,
            instrument: instrument,
            values: values,
            boundaryConditions: boundaryConditions,
            suspectedLimitations: suspectedLimitations,
            absenceReason: absenceReason,
            confidence: confidence,
            evidenceIDs: evidenceIDs,
            provenance: TwinProvenance(
                source: provenance.source.nilIfEmpty ?? source,
                observedAt: provenance.observedAt ?? observedAt,
                observedBy: provenance.observedBy.nilIfEmpty ?? observedBy.nilIfEmpty ?? visit.exportedObserver(source: source),
                notes: provenance.notes ?? notes
            ),
            notes: notes
        )
    }
}

private extension ServicePointObservation {
    func exportedDaedalusServicePointObservation(source: String, visit: Visit) -> ServicePointObservation {
        ServicePointObservation(
            id: id,
            areaID: areaID,
            servicePointType: servicePointType,
            supplyType: supplyType,
            intendedPressureType: intendedPressureType,
            servedByAssetIDs: servedByAssetIDs,
            observedIssues: observedIssues,
            evidenceIDs: evidenceIDs,
            confidence: confidence,
            provenance: TwinProvenance(
                source: provenance.source.nilIfEmpty ?? source,
                observedAt: provenance.observedAt ?? visit.createdAt,
                observedBy: provenance.observedBy.nilIfEmpty ?? visit.exportedObserver(source: source),
                notes: provenance.notes ?? notes
            ),
            notes: notes
        )
    }
}

private extension SystemComponentKind {
    var exportedObservationTag: String {
        switch self {
        case .boiler:
            return "boiler"
        case .cylinder:
            return "cylinder"
        case .radiator:
            return "radiator"
        case .controls:
            return "controls"
        case .pump:
            return "pump"
        case .flue:
            return "flue"
        case .gasMeter:
            return "gas meter"
        case .feedAndExpansion:
            return "feed and expansion"
        case .pipework:
            return "pipework"
        case .other:
            return "unknown"
        }
    }

    var exportedAssetType: SystemAssetType {
        switch self {
        case .boiler:
            return .boiler
        case .cylinder:
            return .cylinder
        case .radiator:
            return .radiator
        case .controls:
            return .control
        case .pump:
            return .pump
        case .flue:
            return .flue
        case .gasMeter:
            return .meter
        case .feedAndExpansion, .pipework, .other:
            return .unknown
        }
    }
}

private extension SpatialConfidence {
    var exportedConfidence: Confidence {
        switch self {
        case .high, .medium:
            return .observed
        case .low:
            return .approximate
        case .unknown:
            return .unknown
        }
    }
}

private extension Evidence {
    func exportedDaedalusEvidence(
        source: String,
        visit: Visit,
        assetRef: String
    ) -> DaedalusObservation {
        DaedalusObservation(
            observationID: id.uuidString,
            tag: kind.exportedObservationTag,
            name: kind.exportedTitle,
            assetRef: assetRef,
            fileRef: localFileName.nilIfEmpty,
            confidence: kind == .photo || kind == .voiceNote ? .observed : .approximate,
            provenance: TwinProvenance(
                source: source,
                observedAt: createdAt,
                observedBy: visit.exportedObserver(source: source),
                notes: reviewNotes
            )
        )
    }
}

private extension EvidenceKind {
    var exportedObservationTag: String {
        switch self {
        case .photo:
            return "photo evidence"
        case .voiceNote:
            return "voice evidence"
        case .textNote:
            return "text evidence"
        }
    }

    var exportedTitle: String {
        switch self {
        case .photo:
            return "Photo"
        case .voiceNote:
            return "Voice Note"
        case .textNote:
            return "Text Note"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        switch self {
        case let .some(value):
            return value.nilIfEmpty
        case .none:
            return nil
        }
    }
}

private extension Visit {
    func exportedHomeObservation(source: String) -> DaedalusObservation? {
        let parts = [
            customerName.nilIfEmpty,
            addressLine.nilIfEmpty,
            postcode.nilIfEmpty,
            notes.nilIfEmpty
        ].compactMap { $0 }
        guard !parts.isEmpty else {
            return nil
        }

        return DaedalusObservation(
            observationID: "\(id.uuidString)-home-context",
            tag: "surveyor note",
            name: customerName.nilIfEmpty,
            notes: parts.joined(separator: "\n"),
            provenance: TwinProvenance(
                source: source,
                observedAt: createdAt,
                observedBy: exportedObserver(source: source)
            )
        )
    }

    func exportedObserver(source: String) -> String {
        engineerName.nilIfEmpty ?? source
    }
}
