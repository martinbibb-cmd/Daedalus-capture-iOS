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

    public init(
        packageVersion: Int = currentPackageVersion,
        packageID: UUID = UUID(),
        visitID: UUID,
        propertyRef: String,
        createdAt: Date = Date(),
        observations: [DaedalusObservation],
        relationships: [DaedalusRelationship] = []
    ) {
        self.packageVersion = packageVersion
        self.packageID = packageID
        self.visitID = visitID
        self.propertyRef = propertyRef
        self.createdAt = createdAt
        self.observations = observations
        self.relationships = relationships
    }

    enum CodingKeys: String, CodingKey {
        case packageVersion
        case packageID = "packageId"
        case visitID = "visitId"
        case propertyRef
        case createdAt = "captured_at"
        case observations
        case relationships
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
            relationships: visit.relationships.compactMap { $0.exportedDaedalusRelationship(source: source, visit: visit) }
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
