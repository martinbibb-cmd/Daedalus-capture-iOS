import Foundation

enum CaptureSuggestionSource: String, CaseIterable, Hashable {
    case machineVision
    case transcript
    case spatialContext
    case manualTap
    case existingEvidence

    var title: String {
        switch self {
        case .machineVision: return "Machine Vision"
        case .transcript: return "Transcript"
        case .spatialContext: return "Spatial Context"
        case .manualTap: return "Manual Tap"
        case .existingEvidence: return "Existing Evidence"
        }
    }
}

enum CaptureSuggestionReviewState: String, CaseIterable, Hashable {
    case suggested
    case confirmed
    case changed
    case ignored
    case unresolved
    case needsAttention

    var title: String {
        switch self {
        case .suggested: return "Suggested"
        case .confirmed: return "Confirmed"
        case .changed: return "Changed"
        case .ignored: return "Ignored"
        case .unresolved: return "Unresolved"
        case .needsAttention: return "Needs attention"
        }
    }
}

struct SuggestedArea: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var context: String

    init(id: UUID = UUID(), name: String, context: String) {
        self.id = id
        self.name = name
        self.context = context
    }
}

enum SuggestedAreaReviewState: String, CaseIterable, Hashable {
    case suggested
    case confirmed
    case renamed
    case merged
    case ignored
    case unresolved

    var title: String {
        switch self {
        case .suggested: return "Suggested"
        case .confirmed: return "Confirmed"
        case .renamed: return "Renamed"
        case .merged: return "Merged"
        case .ignored: return "Ignored"
        case .unresolved: return "Unresolved"
        }
    }
}

enum SuggestedAreaCategory: String, CaseIterable, Hashable {
    case room
    case circulation
    case external
    case serviceArea
    case unresolved

    var title: String {
        switch self {
        case .room: return "Room"
        case .circulation: return "Circulation"
        case .external: return "External"
        case .serviceArea: return "Service Area"
        case .unresolved: return "Unresolved"
        }
    }
}

struct SuggestedAreaEvidenceLink: Identifiable, Equatable, Hashable {
    let id: UUID
    let evidenceID: UUID
    let label: String
    let sourceDescription: String

    init(
        id: UUID = UUID(),
        evidenceID: UUID,
        label: String,
        sourceDescription: String
    ) {
        self.id = id
        self.evidenceID = evidenceID
        self.label = label
        self.sourceDescription = sourceDescription
    }
}

struct SuggestedAreaObjectLink: Identifiable, Equatable, Hashable {
    let id: UUID
    let objectID: UUID
    let label: String
    let evidenceCount: Int

    init(
        id: UUID = UUID(),
        objectID: UUID,
        label: String,
        evidenceCount: Int
    ) {
        self.id = id
        self.objectID = objectID
        self.label = label
        self.evidenceCount = evidenceCount
    }
}

struct SuggestedAreaGroup: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var category: SuggestedAreaCategory
    var reviewState: SuggestedAreaReviewState
    var evidenceLinks: [SuggestedAreaEvidenceLink]
    var objectLinks: [SuggestedAreaObjectLink]
    var auditTrail: [String]

    var evidenceCount: Int { evidenceLinks.count }
    var objectCount: Int { objectLinks.count }

    init(
        id: UUID = UUID(),
        name: String,
        category: SuggestedAreaCategory,
        reviewState: SuggestedAreaReviewState = .suggested,
        evidenceLinks: [SuggestedAreaEvidenceLink] = [],
        objectLinks: [SuggestedAreaObjectLink] = [],
        auditTrail: [String] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.reviewState = reviewState
        self.evidenceLinks = evidenceLinks
        self.objectLinks = objectLinks
        self.auditTrail = auditTrail
    }
}

struct SuggestedObject: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var context: String

    init(id: UUID = UUID(), name: String, context: String) {
        self.id = id
        self.name = name
        self.context = context
    }
}

enum SpecialObject: String, CaseIterable, Hashable {
    case doorway
    case externalWall
    case serviceCupboard
    case airingCupboard
    case loftHatch
    case gasEntry
    case waterEntry
    case electricIntake
    case flueExit
    case hiddenObjectMarker
    case obscuredRadiator
    case cylinderAbove
    case tankAbove
    case unresolvedSpecialObject

    var title: String {
        switch self {
        case .doorway: return "Doorway"
        case .externalWall: return "External Wall"
        case .serviceCupboard: return "Service Cupboard"
        case .airingCupboard: return "Airing Cupboard"
        case .loftHatch: return "Loft Hatch"
        case .gasEntry: return "Gas Entry"
        case .waterEntry: return "Water Entry"
        case .electricIntake: return "Electric Intake"
        case .flueExit: return "Flue Exit"
        case .hiddenObjectMarker: return "Hidden Object Marker"
        case .obscuredRadiator: return "Obscured Radiator"
        case .cylinderAbove: return "Cylinder Above"
        case .tankAbove: return "Tank Above"
        case .unresolvedSpecialObject: return "Unresolved Special Object"
        }
    }
}

struct CaptureSuggestion: Identifiable, Equatable, Hashable {
    enum Kind: String, Hashable {
        case area
        case object
        case specialObject
    }

    let id: UUID
    var kind: Kind
    var title: String
    var detail: String
    var sources: [CaptureSuggestionSource]
    var evidenceLabels: [String]
    var reviewState: CaptureSuggestionReviewState
    var suggestedArea: SuggestedArea?
    var suggestedObject: SuggestedObject?
    var specialObject: SpecialObject?
    var linkedComponentID: UUID?

    init(
        id: UUID = UUID(),
        kind: Kind,
        title: String,
        detail: String,
        sources: [CaptureSuggestionSource],
        evidenceLabels: [String],
        reviewState: CaptureSuggestionReviewState = .suggested,
        suggestedArea: SuggestedArea? = nil,
        suggestedObject: SuggestedObject? = nil,
        specialObject: SpecialObject? = nil,
        linkedComponentID: UUID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.sources = sources
        self.evidenceLabels = evidenceLabels
        self.reviewState = reviewState
        self.suggestedArea = suggestedArea
        self.suggestedObject = suggestedObject
        self.specialObject = specialObject
        self.linkedComponentID = linkedComponentID
    }
}

extension Visit {
    static let allowedSuggestedAreaNames = [
        "Kitchen",
        "Utility",
        "Hall",
        "Landing",
        "Lounge",
        "Dining Room",
        "Bedroom",
        "Bathroom",
        "Ensuite",
        "Airing Cupboard",
        "Loft",
        "Garage",
        "Outside",
        "Unknown Area"
    ]

    var captureSuggestionFoundation: [CaptureSuggestion] {
        var suggestions = suggestedAreas + suggestedObjects + suggestedSpecialObjects
        if suggestions.isEmpty {
            suggestions.append(
                CaptureSuggestion(
                    kind: .area,
                    title: "Unclassified capture area",
                    detail: "Placeholder suggestion until room detection is available.",
                    sources: [.existingEvidence],
                    evidenceLabels: ["Evidence pending"],
                    suggestedArea: SuggestedArea(
                        name: "Unclassified capture area",
                        context: "Placeholder suggestion until room detection is available."
                    )
                )
            )
        }
        return suggestions
    }

    var suggestedAreaGroups: [SuggestedAreaGroup] {
        var groupsByID: [UUID: SuggestedAreaGroup] = [:]
        var groupIDsByRoomID: [UUID: UUID] = [:]
        var groupIDsByLabel: [String: UUID] = [:]

        for room in rooms {
            let name = normalizedSuggestedAreaName(room.name)
            let groupID = stableSuggestionID("area-group-room-\(room.id.uuidString)")
            groupIDsByRoomID[room.id] = groupID
            groupIDsByLabel[normalizedAreaKey(name)] = groupID
            groupsByID[groupID] = SuggestedAreaGroup(
                id: groupID,
                name: name,
                category: suggestedAreaCategory(for: name),
                reviewState: room.reviewStatus.suggestedAreaReviewState,
                evidenceLinks: room.evidence.map { evidence in
                    SuggestedAreaEvidenceLink(
                        id: stableSuggestionID("area-evidence-\(room.id.uuidString)-\(evidence.id.uuidString)"),
                        evidenceID: evidence.id,
                        label: evidence.kind.title,
                        sourceDescription: room.name
                    )
                },
                auditTrail: ["suggested from existing room data"]
            )
        }

        for component in components.sorted(by: { $0.createdAtFallback < $1.createdAtFallback }) {
            let groupID = suggestedAreaGroupID(
                for: component,
                groupsByID: &groupsByID,
                groupIDsByRoomID: groupIDsByRoomID,
                groupIDsByLabel: &groupIDsByLabel
            )

            groupsByID[groupID]?.objectLinks.append(
                SuggestedAreaObjectLink(
                    id: stableSuggestionID("area-object-\(groupID.uuidString)-\(component.id.uuidString)"),
                    objectID: component.id,
                    label: component.suggestedCaptureLabel,
                    evidenceCount: component.evidence.count
                )
            )

            groupsByID[groupID]?.evidenceLinks.append(
                contentsOf: component.evidence.map { evidence in
                    SuggestedAreaEvidenceLink(
                        id: stableSuggestionID("area-evidence-\(groupID.uuidString)-\(evidence.id.uuidString)"),
                        evidenceID: evidence.id,
                        label: evidence.kind.title,
                        sourceDescription: component.suggestedCaptureLabel
                    )
                }
            )
        }

        if groupsByID.isEmpty {
            let groupID = stableSuggestionID("area-group-placeholder-\(id.uuidString)")
            groupsByID[groupID] = SuggestedAreaGroup(
                id: groupID,
                name: "Unknown Area",
                category: .unresolved,
                auditTrail: ["placeholder from empty capture sequence"]
            )
        }

        return groupsByID.values.sorted { lhs, rhs in
            if lhs.reviewState == .unresolved && rhs.reviewState != .unresolved {
                return false
            }
            if lhs.reviewState != .unresolved && rhs.reviewState == .unresolved {
                return true
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private var suggestedAreas: [CaptureSuggestion] {
        suggestedAreaGroups.map { group in
            CaptureSuggestion(
                id: stableSuggestionID("area-\(group.id.uuidString)"),
                kind: .area,
                title: group.name,
                detail: "\(group.category.title) - \(group.evidenceCount) evidence, \(group.objectCount) objects",
                sources: [.spatialContext, .existingEvidence],
                evidenceLabels: group.evidenceLinks.map(\.label),
                reviewState: group.reviewState.captureSuggestionState,
                suggestedArea: SuggestedArea(
                    id: group.id,
                    name: group.name,
                    context: group.category.title
                )
            )
        }
    }

    private var suggestedObjects: [CaptureSuggestion] {
        liveCaptureEvidenceComponents.map { component in
            CaptureSuggestion(
                id: stableSuggestionID("object-\(component.id.uuidString)"),
                kind: .object,
                title: component.suggestedCaptureLabel,
                detail: component.spatialContext?.displaySummary ?? component.liveCaptureTitle,
                sources: component.captureSuggestionSources,
                evidenceLabels: component.evidenceLabels,
                reviewState: component.captureReviewDecision.captureSuggestionState,
                suggestedObject: SuggestedObject(
                    id: component.id,
                    name: component.suggestedCaptureLabel,
                    context: component.liveCaptureTitle
                ),
                linkedComponentID: component.id
            )
        }
    }

    private var suggestedSpecialObjects: [CaptureSuggestion] {
        let spatialComponents = liveCaptureEvidenceComponents.filter { component in
            component.liveCaptureEvidenceKind == .mark || component.liveCaptureEvidenceKind == .safety
        }

        if spatialComponents.isEmpty {
            return [
                CaptureSuggestion(
                    id: stableSuggestionID("special-placeholder-\(id.uuidString)"),
                    kind: .specialObject,
                    title: SpecialObject.unresolvedSpecialObject.title,
                    detail: "Placeholder special object awaiting human confirmation.",
                    sources: [.manualTap, .spatialContext],
                    evidenceLabels: ["Spatial Marker"],
                    specialObject: .unresolvedSpecialObject
                )
            ]
        }

        return spatialComponents.map { component in
            let specialObject: SpecialObject = component.liveCaptureEvidenceKind == .safety ? .hiddenObjectMarker : .unresolvedSpecialObject
            return CaptureSuggestion(
                id: stableSuggestionID("special-\(component.id.uuidString)"),
                kind: .specialObject,
                title: specialObject.title,
                detail: component.spatialContext?.displaySummary ?? "Spatial/context object",
                sources: [.manualTap, .spatialContext, .existingEvidence],
                evidenceLabels: component.evidenceLabels,
                reviewState: component.captureReviewDecision.captureSuggestionState,
                specialObject: specialObject,
                linkedComponentID: component.id
            )
        }
    }
}

private extension Visit {
    func suggestedAreaGroupID(
        for component: SystemComponent,
        groupsByID: inout [UUID: SuggestedAreaGroup],
        groupIDsByRoomID: [UUID: UUID],
        groupIDsByLabel: inout [String: UUID]
    ) -> UUID {
        if let roomID = relationships.first(where: {
            $0.sourceComponentID == component.id &&
                $0.relationship == .containedIn &&
                $0.targetAreaID != nil
        })?.targetAreaID,
           let groupID = groupIDsByRoomID[roomID] {
            return groupID
        }

        let rawLabel = component.spatialContext?.areaLabel ??
            component.componentAttributes["location"] ??
            "Unknown Area"
        let name = normalizedSuggestedAreaName(rawLabel)
        let labelKey = normalizedAreaKey(name)
        if let groupID = groupIDsByLabel[labelKey] {
            return groupID
        }

        let groupID = stableSuggestionID("area-group-label-\(labelKey)-\(id.uuidString)")
        groupIDsByLabel[labelKey] = groupID
        groupsByID[groupID] = SuggestedAreaGroup(
            id: groupID,
            name: name,
            category: suggestedAreaCategory(for: name),
            auditTrail: ["suggested from evidence cluster and spatial context"]
        )
        return groupID
    }
}

private extension SuggestedAreaReviewState {
    var captureSuggestionState: CaptureSuggestionReviewState {
        switch self {
        case .suggested:
            return .suggested
        case .confirmed:
            return .confirmed
        case .renamed:
            return .changed
        case .merged:
            return .changed
        case .ignored:
            return .ignored
        case .unresolved:
            return .unresolved
        }
    }
}

private extension Optional where Wrapped == ReviewStatus {
    var captureSuggestionState: CaptureSuggestionReviewState {
        switch self {
        case .confirmed:
            return .confirmed
        case .changed:
            return .changed
        case .ignored:
            return .ignored
        case .needsAttention:
            return .needsAttention
        case .unreviewed, .needsReview, .draft, .rejected, .none:
            return .suggested
        }
    }
}

private extension Optional where Wrapped == ReviewStatus {
    var suggestedAreaReviewState: SuggestedAreaReviewState {
        switch self {
        case .confirmed:
            return .confirmed
        case .changed:
            return .renamed
        case .ignored:
            return .ignored
        case .needsAttention, .rejected:
            return .unresolved
        case .unreviewed, .needsReview, .draft, .none:
            return .suggested
        }
    }
}

private extension SystemComponent {
    var createdAtFallback: Date {
        evidence.map(\.createdAt).min() ?? Date()
    }
}

private extension CaptureReviewDecision {
    var captureSuggestionState: CaptureSuggestionReviewState {
        switch self {
        case .unreviewed:
            return .suggested
        case .confirmed:
            return .confirmed
        case .changed:
            return .changed
        case .ignored:
            return .ignored
        case .needsAttention:
            return .needsAttention
        }
    }
}

private extension SystemComponent {
    var captureSuggestionSources: [CaptureSuggestionSource] {
        var sources: [CaptureSuggestionSource] = [.existingEvidence]
        if componentAttributes["transcriptSnippet"] != nil || componentAttributes["voiceNoteTranscript"] != nil {
            sources.append(.transcript)
        }
        if spatialContext != nil || !(spatialPlacement.anchorID?.isEmpty ?? true) {
            sources.append(.spatialContext)
        }
        if liveCaptureEvidenceKind == .mark || liveCaptureEvidenceKind == .safety {
            sources.append(.manualTap)
        }
        return Array(Set(sources)).sorted { $0.title < $1.title }
    }
}

private extension Room {
    var evidenceLabels: [String] {
        let labels = evidence.map(\.kind.title)
        return labels.isEmpty ? ["Spatial Marker"] : Array(Set(labels)).sorted()
    }
}

private extension SystemComponent {
    var evidenceLabels: [String] {
        let labels = evidence.map(\.kind.title)
        return labels.isEmpty ? ["Spatial Marker"] : Array(Set(labels)).sorted()
    }
}

private func normalizedSuggestedAreaName(_ rawName: String) -> String {
    let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "Unknown Area" }

    let lowercased = trimmed.lowercased()
    let matches: [(String, String)] = [
        ("kitchen", "Kitchen"),
        ("utility", "Utility"),
        ("hall", "Hall"),
        ("landing", "Landing"),
        ("lounge", "Lounge"),
        ("living", "Lounge"),
        ("dining", "Dining Room"),
        ("bed", "Bedroom"),
        ("bath", "Bathroom"),
        ("ensuite", "Ensuite"),
        ("airing", "Airing Cupboard"),
        ("loft", "Loft"),
        ("garage", "Garage"),
        ("outside", "Outside"),
        ("external", "Outside")
    ]

    if let match = matches.first(where: { lowercased.contains($0.0) }) {
        return match.1
    }
    if Visit.allowedSuggestedAreaNames.contains(trimmed) {
        return trimmed
    }
    return "Unknown Area"
}

private func suggestedAreaCategory(for name: String) -> SuggestedAreaCategory {
    switch name {
    case "Hall", "Landing":
        return .circulation
    case "Outside", "Garage":
        return .external
    case "Utility", "Airing Cupboard", "Loft":
        return .serviceArea
    case "Unknown Area":
        return .unresolved
    default:
        return .room
    }
}

private func normalizedAreaKey(_ name: String) -> String {
    name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
}

private func stableSuggestionID(_ value: String) -> UUID {
    let namespace = UUID(uuidString: "DAEDA111-1111-4111-8111-111111111111")!
    let uuid = namespace.uuid
    var bytes = [
        uuid.0, uuid.1, uuid.2, uuid.3,
        uuid.4, uuid.5, uuid.6, uuid.7,
        uuid.8, uuid.9, uuid.10, uuid.11,
        uuid.12, uuid.13, uuid.14, uuid.15
    ]
    for (index, byte) in value.utf8.enumerated() {
        bytes[index % bytes.count] = bytes[index % bytes.count] &+ byte &+ UInt8(index & 0xFF)
    }
    return UUID(uuid: (
        bytes[0], bytes[1], bytes[2], bytes[3],
        bytes[4], bytes[5],
        bytes[6], bytes[7],
        bytes[8], bytes[9],
        bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
    ))
}
