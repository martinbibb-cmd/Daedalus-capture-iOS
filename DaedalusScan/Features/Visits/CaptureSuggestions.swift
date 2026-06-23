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

struct AreaEvidenceSummary: Equatable, Hashable {
    var evidenceLinks: [SuggestedAreaEvidenceLink]

    var evidenceCount: Int { evidenceLinks.count }
    var labels: [String] {
        Array(Set(evidenceLinks.map(\.label))).sorted()
    }

    init(evidenceLinks: [SuggestedAreaEvidenceLink] = []) {
        self.evidenceLinks = evidenceLinks
    }
}

struct AreaObjectReviewSummary: Identifiable, Equatable, Hashable {
    let id: UUID
    let objectID: UUID
    var label: String
    var reviewState: CaptureSuggestionReviewState
    var evidenceSummary: AreaEvidenceSummary

    init(
        id: UUID = UUID(),
        objectID: UUID,
        label: String,
        reviewState: CaptureSuggestionReviewState,
        evidenceSummary: AreaEvidenceSummary
    ) {
        self.id = id
        self.objectID = objectID
        self.label = label
        self.reviewState = reviewState
        self.evidenceSummary = evidenceSummary
    }
}

struct AreaSpecialObjectGroup: Identifiable, Equatable, Hashable {
    let id: UUID
    var specialObject: SpecialObject
    var label: String
    var reviewState: CaptureSuggestionReviewState
    var evidenceSummary: AreaEvidenceSummary
    var linkedComponentID: UUID?

    init(
        id: UUID = UUID(),
        specialObject: SpecialObject,
        label: String,
        reviewState: CaptureSuggestionReviewState,
        evidenceSummary: AreaEvidenceSummary,
        linkedComponentID: UUID? = nil
    ) {
        self.id = id
        self.specialObject = specialObject
        self.label = label
        self.reviewState = reviewState
        self.evidenceSummary = evidenceSummary
        self.linkedComponentID = linkedComponentID
    }
}

struct AreaObjectGroup: Identifiable, Equatable, Hashable {
    let id: UUID
    var area: SuggestedAreaGroup
    var objects: [AreaObjectReviewSummary]
    var specialObjects: [AreaSpecialObjectGroup]
    var evidenceSummary: AreaEvidenceSummary

    init(
        id: UUID = UUID(),
        area: SuggestedAreaGroup,
        objects: [AreaObjectReviewSummary] = [],
        specialObjects: [AreaSpecialObjectGroup] = [],
        evidenceSummary: AreaEvidenceSummary = AreaEvidenceSummary()
    ) {
        self.id = id
        self.area = area
        self.objects = objects
        self.specialObjects = specialObjects
        self.evidenceSummary = evidenceSummary
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

enum CaptureConfirmationType: String, CaseIterable, Hashable {
    case objectSuggestion
    case areaSuggestion
    case specialObjectSuggestion
    case unresolvedCapture
    case evidenceAttached
    case relationshipSuggestion

    var title: String {
        switch self {
        case .objectSuggestion: return "Object Suggestion"
        case .areaSuggestion: return "Area Suggestion"
        case .specialObjectSuggestion: return "Special Object Suggestion"
        case .unresolvedCapture: return "Unresolved Capture"
        case .evidenceAttached: return "Evidence Attached"
        case .relationshipSuggestion: return "Relationship Suggestion"
        }
    }
}

struct CaptureSuggestionPreview: Identifiable, Equatable, Hashable {
    let id: UUID
    var observedEvidence: [String]
    var suggestedTitle: String
    var areaName: String
    var status: CaptureSuggestionReviewState
    var linkedComponentID: UUID?

    init(
        id: UUID = UUID(),
        observedEvidence: [String],
        suggestedTitle: String,
        areaName: String,
        status: CaptureSuggestionReviewState,
        linkedComponentID: UUID? = nil
    ) {
        self.id = id
        self.observedEvidence = observedEvidence
        self.suggestedTitle = suggestedTitle
        self.areaName = areaName
        self.status = status
        self.linkedComponentID = linkedComponentID
    }
}

struct CaptureConfirmationEvent: Identifiable, Equatable, Hashable {
    let id: UUID
    var type: CaptureConfirmationType
    var preview: CaptureSuggestionPreview
    var createdAt: Date

    init(
        id: UUID = UUID(),
        type: CaptureConfirmationType,
        preview: CaptureSuggestionPreview,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.preview = preview
        self.createdAt = createdAt
    }
}

struct LiveCaptureConfirmationState: Equatable, Hashable {
    var activeEvent: CaptureConfirmationEvent?
    var recentEvents: [CaptureConfirmationEvent]

    init(
        activeEvent: CaptureConfirmationEvent? = nil,
        recentEvents: [CaptureConfirmationEvent] = []
    ) {
        self.activeEvent = activeEvent
        self.recentEvents = recentEvents
    }

    mutating func record(_ event: CaptureConfirmationEvent, limit: Int = 6) {
        activeEvent = event
        recentEvents.insert(event, at: 0)
        if recentEvents.count > limit {
            recentEvents.removeLast(recentEvents.count - limit)
        }
    }

    mutating func update(componentID: UUID, status: CaptureSuggestionReviewState) {
        if activeEvent?.preview.linkedComponentID == componentID {
            activeEvent?.preview.status = status
        }
        recentEvents = recentEvents.map { event in
            guard event.preview.linkedComponentID == componentID else { return event }
            var updated = event
            updated.preview.status = status
            return updated
        }
    }
}

struct TranscriptSuggestionCandidate: Identifiable, Equatable, Hashable {
    let id: UUID
    var transcriptID: UUID?
    var heardText: String
    var suggestedTitle: String
    var confidence: SpatialConfidence

    init(
        id: UUID = UUID(),
        transcriptID: UUID? = nil,
        heardText: String,
        suggestedTitle: String,
        confidence: SpatialConfidence = .unknown
    ) {
        self.id = id
        self.transcriptID = transcriptID
        self.heardText = heardText
        self.suggestedTitle = suggestedTitle
        self.confidence = confidence
    }
}

struct VisionSuggestionCandidate: Identifiable, Equatable, Hashable {
    let id: UUID
    var evidenceID: UUID?
    var suggestedTitle: String
    var confidence: SpatialConfidence

    init(
        id: UUID = UUID(),
        evidenceID: UUID? = nil,
        suggestedTitle: String,
        confidence: SpatialConfidence = .unknown
    ) {
        self.id = id
        self.evidenceID = evidenceID
        self.suggestedTitle = suggestedTitle
        self.confidence = confidence
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

    var areaObjectGroups: [AreaObjectGroup] {
        suggestedAreaGroups.map { area in
            let placedComponents = components.filter { component in
                area.objectLinks.contains { $0.objectID == component.id }
            }
            let regularObjects = placedComponents
                .filter { !$0.isSpatialSpecialObjectSuggestion }
                .map { component in
                    AreaObjectReviewSummary(
                        id: stableSuggestionID("area-object-summary-\(area.id.uuidString)-\(component.id.uuidString)"),
                        objectID: component.id,
                        label: component.suggestedCaptureLabel,
                        reviewState: component.captureReviewDecision.captureSuggestionState,
                        evidenceSummary: AreaEvidenceSummary(evidenceLinks: component.areaEvidenceLinks(areaID: area.id))
                    )
                }
            let specialObjects = placedComponents
                .filter(\.isSpatialSpecialObjectSuggestion)
                .map { component in
                    let specialObject = component.suggestedSpecialObject
                    return AreaSpecialObjectGroup(
                        id: stableSuggestionID("area-special-summary-\(area.id.uuidString)-\(component.id.uuidString)"),
                        specialObject: specialObject,
                        label: specialObject.title,
                        reviewState: component.captureReviewDecision.captureSuggestionState,
                        evidenceSummary: AreaEvidenceSummary(evidenceLinks: component.areaEvidenceLinks(areaID: area.id)),
                        linkedComponentID: component.id
                    )
                }

            return AreaObjectGroup(
                id: stableSuggestionID("area-object-group-\(area.id.uuidString)"),
                area: area,
                objects: regularObjects,
                specialObjects: specialObjects,
                evidenceSummary: AreaEvidenceSummary(evidenceLinks: area.evidenceLinks)
            )
        }
    }

    func captureConfirmationEvent(for componentID: UUID) -> CaptureConfirmationEvent? {
        guard let component = components.first(where: { $0.id == componentID }),
              let liveKind = component.liveCaptureEvidenceKind else {
            return nil
        }
        let areaName = suggestedAreaName(for: component)
        let preview = CaptureSuggestionPreview(
            id: stableSuggestionID("capture-preview-\(component.id.uuidString)"),
            observedEvidence: component.liveCaptureObservedEvidenceLabels,
            suggestedTitle: component.liveCaptureSuggestionTitle,
            areaName: areaName,
            status: component.liveCaptureConfirmationStatus,
            linkedComponentID: component.id
        )
        return CaptureConfirmationEvent(
            id: stableSuggestionID("capture-confirmation-\(component.id.uuidString)"),
            type: confirmationType(for: component, liveKind: liveKind),
            preview: preview,
            createdAt: component.createdAtFallback
        )
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
            let specialObject = component.suggestedSpecialObject
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
    func confirmationType(for component: SystemComponent, liveKind: LiveCaptureEvidenceKind) -> CaptureConfirmationType {
        if component.captureReviewDecision == .needsAttention {
            return .unresolvedCapture
        }
        switch liveKind {
        case .safety:
            return .unresolvedCapture
        case .mark:
            return component.suggestedSpecialObject == .unresolvedSpecialObject ? .relationshipSuggestion : .specialObjectSuggestion
        case .photo, .voice, .measurement:
            return component.suggestedCaptureLabel == liveKind.defaultSuggestedLabel ? .evidenceAttached : .objectSuggestion
        }
    }

    func suggestedAreaName(for component: SystemComponent) -> String {
        areaObjectGroups.first { group in
            group.objects.contains { $0.objectID == component.id } ||
                group.specialObjects.contains { $0.linkedComponentID == component.id }
        }?.area.name ?? normalizedSuggestedAreaName(component.suggestedAreaLabel)
    }

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

        let rawLabel = component.suggestedAreaLabel
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
    var isSpatialSpecialObjectSuggestion: Bool {
        liveCaptureEvidenceKind == .mark || liveCaptureEvidenceKind == .safety
    }

    var suggestedSpecialObject: SpecialObject {
        if liveCaptureEvidenceKind == .safety {
            return .hiddenObjectMarker
        }
        let text = [
            suggestedCaptureLabel,
            componentAttributes["transcriptSnippet"] ?? "",
            componentAttributes["voiceNoteTranscript"] ?? "",
            spatialContext?.areaLabel ?? "",
            spatialContext?.approximatePositionLabel ?? ""
        ]
        .joined(separator: " ")
        .lowercased()

        if text.contains("service cupboard") { return .serviceCupboard }
        if text.contains("airing") { return .airingCupboard }
        if text.contains("loft") { return .loftHatch }
        if text.contains("flue") { return .flueExit }
        if text.contains("door") { return .doorway }
        if text.contains("external wall") { return .externalWall }
        return .unresolvedSpecialObject
    }

    func areaEvidenceLinks(areaID: UUID) -> [SuggestedAreaEvidenceLink] {
        evidence.map { evidence in
            SuggestedAreaEvidenceLink(
                id: stableSuggestionID("area-object-evidence-\(areaID.uuidString)-\(id.uuidString)-\(evidence.id.uuidString)"),
                evidenceID: evidence.id,
                label: evidence.kind.title,
                sourceDescription: suggestedCaptureLabel
            )
        }
    }

    var liveCaptureSuggestionTitle: String {
        guard isSpatialSpecialObjectSuggestion else {
            return suggestedCaptureLabel
        }
        let title = suggestedSpecialObject.title
        return suggestedSpecialObject == .unresolvedSpecialObject ? "Unknown Object" : title
    }

    var liveCaptureConfirmationStatus: CaptureSuggestionReviewState {
        if captureReviewDecision == .needsAttention {
            return .unresolved
        }
        return captureReviewDecision.captureSuggestionState
    }

    var liveCaptureObservedEvidenceLabels: [String] {
        var labels = evidence.map { evidence in
            switch evidence.kind {
            case .photo:
                return "Photo"
            case .voiceNote:
                return "Voice Note"
            case .textNote:
                return liveCaptureEvidenceKind == .mark || liveCaptureEvidenceKind == .safety ? "Spatial Marker" : "Text Note"
            default:
                return evidence.kind.title
            }
        }
        if isSpatialSpecialObjectSuggestion && labels.isEmpty {
            labels.append("Spatial Marker")
        }
        return Array(Set(labels)).sorted()
    }

    var suggestedAreaLabel: String {
        let candidates = [
            componentAttributes["location"],
            spatialContext?.areaLabel,
            spatialContext?.approximatePositionLabel,
            componentAttributes["positionLabel"]
        ]
        for candidate in candidates {
            guard let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty,
                  trimmed != "Unclassified evidence",
                  trimmed != "Spatial capture",
                  trimmed != "Room understood",
                  trimmed != "Building room outline",
                  trimmed != "Move around for more detail" else {
                continue
            }
            return trimmed
        }
        return "Unknown Area"
    }

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
