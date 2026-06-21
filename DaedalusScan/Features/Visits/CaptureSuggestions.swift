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

    private var suggestedAreas: [CaptureSuggestion] {
        rooms.map { room in
            CaptureSuggestion(
                id: stableSuggestionID("area-\(room.id.uuidString)"),
                kind: .area,
                title: room.name,
                detail: room.spatialPlacement.captureState.title,
                sources: [.spatialContext, .existingEvidence],
                evidenceLabels: room.evidenceLabels,
                reviewState: room.reviewStatus.captureSuggestionState,
                suggestedArea: SuggestedArea(
                    id: room.id,
                    name: room.name,
                    context: room.spatialPlacement.confidence.title
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
