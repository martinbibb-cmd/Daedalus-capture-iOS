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
    public var placement: TwinSpatialPlacement
    public var confidence: Confidence
    public var evidenceIDs: [UUID]

    public init(
        id: UUID = UUID(),
        assetType: SystemAssetType,
        placement: TwinSpatialPlacement,
        confidence: Confidence,
        evidenceIDs: [UUID]
    ) {
        self.id = id
        self.assetType = assetType
        self.placement = placement
        self.confidence = confidence
        self.evidenceIDs = evidenceIDs
    }
}

public struct SystemTwin: Codable, Hashable, Sendable {
    public let id: UUID
    public var assets: [SystemAsset]

    public init(id: UUID = UUID(), assets: [SystemAsset]) {
        self.id = id
        self.assets = assets
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
    public static let currentVersion = "1.0.0"

    public var version: String
    public var packageID: UUID
    public var createdAt: Date
    public var houseTwin: HouseTwin
    public var systemTwin: SystemTwin
    public var homeTwin: HomeTwin
    public var evidence: [TwinEvidence]

    public init(
        version: String = currentVersion,
        packageID: UUID = UUID(),
        createdAt: Date = Date(),
        houseTwin: HouseTwin,
        systemTwin: SystemTwin,
        homeTwin: HomeTwin,
        evidence: [TwinEvidence]
    ) {
        self.version = version
        self.packageID = packageID
        self.createdAt = createdAt
        self.houseTwin = houseTwin
        self.systemTwin = systemTwin
        self.homeTwin = homeTwin
        self.evidence = evidence
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
    let evidenceIDs = Set(packageData.evidence.map(\.id))
    var issues: [PackageValidationIssue] = []

    for (assetIndex, asset) in packageData.systemTwin.assets.enumerated() {
        for (evidenceIndex, evidenceID) in asset.evidenceIDs.enumerated() where !evidenceIDs.contains(evidenceID) {
            issues.append(
                PackageValidationIssue(
                    path: "systemTwin.assets[\(assetIndex)].evidenceIDs[\(evidenceIndex)]",
                    code: "evidence.reference.missing",
                    message: "Evidence ID does not exist in package evidence array: \(evidenceID.uuidString)"
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
            ids: packageData.houseTwin.areas.map(\.id),
            pathPrefix: "houseTwin.areas",
            code: "spatialArea.id.duplicate",
            message: "Duplicate SpatialArea.id"
        )
    )
    issues.append(
        contentsOf: duplicateIDIssues(
            ids: packageData.systemTwin.assets.map(\.id),
            pathPrefix: "systemTwin.assets",
            code: "systemAsset.id.duplicate",
            message: "Duplicate SystemAsset.id"
        )
    )
    issues.append(
        contentsOf: duplicateIDIssues(
            ids: packageData.evidence.map(\.id),
            pathPrefix: "evidence",
            code: "twinEvidence.id.duplicate",
            message: "Duplicate TwinEvidence.id"
        )
    )
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
        let exportedEvidence = roomEvidence(from: visit, source: source) + componentEvidence(from: visit, source: source)
        let houseTwin = HouseTwin(areas: visit.rooms.map(\.exportedSpatialArea))
        let systemTwin = SystemTwin(assets: visit.components.map(\.exportedSystemAsset))
        let homeTwin = HomeTwin(
            occupancyDescription: visit.customerName.nilIfEmpty,
            notes: visit.notes.nilIfEmpty
        )

        return DaedalusPackage(
            packageID: packageID,
            createdAt: createdAt,
            houseTwin: houseTwin,
            systemTwin: systemTwin,
            homeTwin: homeTwin,
            evidence: exportedEvidence
        )
    }

    private static func roomEvidence(from visit: Visit, source: String) -> [TwinEvidence] {
        visit.rooms.flatMap { room in
            room.evidence.map {
                $0.exportedTwinEvidence(
                    source: source,
                    observedBy: visit.engineerName,
                    contextTitle: room.name
                )
            }
        }
    }

    private static func componentEvidence(from visit: Visit, source: String) -> [TwinEvidence] {
        visit.components.flatMap { component in
            component.evidence.map {
                $0.exportedTwinEvidence(
                    source: source,
                    observedBy: visit.engineerName,
                    contextTitle: component.exportedContextTitle
                )
            }
        }
    }
}

private func duplicateIDIssues(
    ids: [UUID],
    pathPrefix: String,
    code: String,
    message: String
) -> [PackageValidationIssue] {
    var seen = Set<UUID>()
    var issues: [PackageValidationIssue] = []

    for (index, id) in ids.enumerated() {
        if seen.contains(id) {
            issues.append(
                PackageValidationIssue(
                    path: "\(pathPrefix)[\(index)].id",
                    code: code,
                    message: "\(message): \(id.uuidString)"
                )
            )
        } else {
            seen.insert(id)
        }
    }

    return issues
}

private extension Room {
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

private extension SystemComponentKind {
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
    func exportedTwinEvidence(
        source: String,
        observedBy: String?,
        contextTitle: String
    ) -> TwinEvidence {
        TwinEvidence(
            id: id,
            title: "\(contextTitle) \(kind.exportedTitle)",
            description: localFileName.nilIfEmpty,
            provenance: TwinProvenance(
                source: source,
                observedAt: createdAt,
                observedBy: observedBy,
                notes: reviewNotes
            ),
            confidence: kind == .photo || kind == .voiceNote ? .observed : .approximate
        )
    }
}

private extension EvidenceKind {
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
