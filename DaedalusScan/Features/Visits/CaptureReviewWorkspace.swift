import SwiftUI
import UIKit

struct CaptureReviewWorkspaceRow: Identifiable, Equatable {
    let id: UUID
    let title: String
    let detail: String
    let capturedAt: Date
    let status: String?
    let systemImage: String
}

struct CaptureReviewWorkspaceSummary: Equatable {
    var recordings: [CaptureReviewWorkspaceRow]
    var transcripts: [CaptureReviewWorkspaceRow]
    var observations: [CaptureReviewWorkspaceRow]
    var photos: [CaptureReviewWorkspaceRow]

    var isEmpty: Bool {
        recordings.isEmpty && transcripts.isEmpty && observations.isEmpty && photos.isEmpty
    }
}

struct CaptureReviewCard: Identifiable, Equatable {
    let id: UUID
    let componentID: UUID
    let evidenceID: UUID?
    let markerType: LiveCaptureEvidenceKind
    let capturedAt: Date
    let photoFileName: String?
    let evidenceType: String
    let areaName: String
    let objectName: String
    let spatialMetadata: [String]
    let transcriptExcerpt: String
    let suggestedLabel: String
    let reviewedLabel: String
    let anchorStatus: String
    let status: ReviewStatus?
    let confidence: String

    var requiresAttention: Bool {
        markerType == .safety && (status == .unreviewed || status == .needsAttention)
    }
}

struct CaptureGeometryReviewSummary: Equatable {
    let areaCount: Int
    let spatialEvidenceCount: Int
    let anchoredCount: Int
    let approximateCount: Int
    let roomPlanCount: Int
    let focusCount: Int
    let manualCount: Int
    let confidence: String
    let coverageStatus: String
    let anchors: [String]

    var hasGeometry: Bool {
        spatialEvidenceCount > 0 || areaCount > 0
    }
}

struct ExpandedEvidencePhoto: Identifiable, Equatable {
    let id: UUID
    let title: String
    let url: URL
}

private enum CaptureReviewSheet: Identifiable {
    case changeEvidence(CaptureReviewCard)
    case areaDetail(SuggestedAreaGroup)
    case renameArea(SuggestedAreaGroup)
    case changeObject(AreaObjectReviewSummary)
    case changeSuggestion(CaptureSuggestion)
    case share(URL)
    case expandedPhoto(ExpandedEvidencePhoto)

    var id: String {
        switch self {
        case .changeEvidence(let card):
            return "change-evidence-\(card.id.uuidString)"
        case .areaDetail(let area):
            return "area-detail-\(area.id.uuidString)"
        case .renameArea(let area):
            return "rename-area-\(area.id.uuidString)"
        case .changeObject(let object):
            return "change-object-\(object.id.uuidString)"
        case .changeSuggestion(let suggestion):
            return "change-suggestion-\(suggestion.id.uuidString)"
        case .share(let url):
            return "share-\(url.path)"
        case .expandedPhoto(let photo):
            return "photo-\(photo.id.uuidString)"
        }
    }
}

extension Visit {
    var captureReviewWorkspaceSummary: CaptureReviewWorkspaceSummary {
        CaptureReviewWorkspaceSummary(
            recordings: recordings
                .sorted { $0.sequenceNumber < $1.sequenceNumber }
                .map { recording in
                    CaptureReviewWorkspaceRow(
                        id: recording.id,
                        title: recording.displayName,
                        detail: recording.localFileName,
                        capturedAt: recording.startedAt,
                        status: recording.status.title,
                        systemImage: "waveform"
                    )
                },
            transcripts: transcripts
                .sorted { $0.createdAt < $1.createdAt }
                .map { transcript in
                    CaptureReviewWorkspaceRow(
                        id: transcript.id,
                        title: "Transcript",
                        detail: transcript.rawTranscript.isEmpty ? transcript.source.localFileName ?? "Recording transcript" : transcript.rawTranscript,
                        capturedAt: transcript.createdAt,
                        status: transcript.status.title,
                        systemImage: "text.quote"
                    )
                },
            observations: rooms.map { room in
                CaptureReviewWorkspaceRow(
                    id: room.id,
                    title: room.name,
                    detail: "Area observation",
                    capturedAt: createdAt,
                    status: room.reviewStatus?.title,
                    systemImage: "square.dashed"
                )
            } + components.flatMap { component in
                component.evidence
                    .filter { $0.kind != .photo }
                    .map { evidence in
                        CaptureReviewWorkspaceRow(
                            id: evidence.id,
                            title: evidence.kind.title,
                            detail: component.liveCaptureTitle,
                            capturedAt: evidence.createdAt,
                            status: evidence.reviewStatus?.title,
                            systemImage: evidence.kind.systemImage
                        )
                    }
            },
            photos: components.flatMap { component in
                component.evidence
                    .filter { $0.kind == .photo }
                    .map { evidence in
                        CaptureReviewWorkspaceRow(
                            id: evidence.id,
                            title: EvidenceKind.photo.title,
                            detail: component.liveCaptureTitle,
                            capturedAt: evidence.createdAt,
                            status: evidence.reviewStatus?.title,
                            systemImage: EvidenceKind.photo.systemImage
                        )
                    }
            }
        )
    }

    var captureReviewCards: [CaptureReviewCard] {
        liveCaptureEvidenceComponents.compactMap { component in
            guard let markerType = component.liveCaptureEvidenceKind else { return nil }
            let primaryEvidence = component.evidence.sorted { $0.createdAt < $1.createdAt }.first
            let photoEvidence = component.evidence.first(where: { $0.kind == .photo })
            return CaptureReviewCard(
                id: component.id,
                componentID: component.id,
                evidenceID: primaryEvidence?.id,
                markerType: markerType,
                capturedAt: primaryEvidence?.createdAt ?? component.createdAtFallback,
                photoFileName: photoEvidence?.localFileName,
                evidenceType: markerType.title,
                areaName: captureReviewAreaName(for: component),
                objectName: component.suggestedCaptureLabel,
                spatialMetadata: component.captureReviewSpatialMetadata(primaryEvidence),
                transcriptExcerpt: component.componentAttributes["transcriptSnippet"] ?? "",
                suggestedLabel: component.suggestedCaptureLabel,
                reviewedLabel: component.reviewedCaptureLabel,
                anchorStatus: component.spatialPlacement.captureState.shortReviewTitle,
                status: component.reviewStatus,
                confidence: component.spatialPlacement.confidence.title
            )
        }
        .sorted { lhs, rhs in
            if lhs.requiresAttention != rhs.requiresAttention {
                return lhs.requiresAttention
            }
            return lhs.capturedAt < rhs.capturedAt
        }
    }

    private var reviewedPackageReadyCount: Int {
        reviewedCaptureEvidenceComponents.count
    }

    var captureReviewSummaryText: String {
        "\(reviewedPackageReadyCount) reviewed / \(liveCaptureEvidenceComponents.count) raw"
    }

    var captureGeometryReviewSummary: CaptureGeometryReviewSummary {
        let spatialEvidence = components.flatMap(\.evidence).filter { $0.geometryMetadata != nil }
        let placements = components.map(\.spatialPlacement) + rooms.map(\.spatialPlacement)
        let metadata = spatialEvidence.compactMap(\.geometryMetadata)
        let confidence = strongestConfidence(from: metadata.map(\.confidence) + placements.map(\.confidence))
        let anchors = components.compactMap { component -> String? in
            if let anchor = component.spatialPlacement.anchorID, !anchor.isEmpty {
                return anchor
            }
            return component.componentAttributes["geometryAnchorID"]
        }

        return CaptureGeometryReviewSummary(
            areaCount: rooms.count,
            spatialEvidenceCount: spatialEvidence.count,
            anchoredCount: placements.filter { $0.captureState == .anchored }.count,
            approximateCount: placements.filter { $0.captureState == .approximate || $0.captureState == .areaReferenceOnly }.count,
            roomPlanCount: metadata.filter { $0.captureMode == .roomPlan }.count,
            focusCount: metadata.filter { $0.captureMode == .focusPointCloud }.count,
            manualCount: metadata.filter { $0.captureMode == .manual || $0.captureMode == .photoOnly }.count,
            confidence: confidence.title,
            coverageStatus: metadata.contains { $0.captureMode == .roomPlan } ? "Room geometry captured" : "Structured spatial evidence",
            anchors: Array(Set(anchors.filter { !$0.isEmpty })).sorted()
        )
    }

    func captureReviewAreaName(for component: SystemComponent) -> String {
        if let group = areaObjectGroups.first(where: { group in
            group.objects.contains { $0.objectID == component.id } ||
                group.specialObjects.contains { $0.linkedComponentID == component.id }
        }) {
            return group.area.name
        }
        let label = component.spatialContext?.areaLabel.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !label.isEmpty && label != "Unclassified evidence" {
            return label
        }
        return "Unknown Area"
    }
}

private extension SystemComponent {
    var createdAtFallback: Date {
        evidence.map(\.createdAt).min() ?? Date()
    }

    func captureReviewSpatialMetadata(_ evidence: Evidence?) -> [String] {
        var values: [String] = []
        values.append(spatialPlacement.captureState.shortReviewTitle)
        values.append(spatialPlacement.confidence.title)
        if let position = spatialContext?.approximatePositionLabel, !position.isEmpty {
            values.append(position)
        }
        if let mode = evidence?.geometryMetadata?.captureMode {
            values.append(mode.reviewTitle)
        } else if let mode = componentAttributes["geometryCaptureMode"], !mode.isEmpty {
            values.append(mode)
        }
        if let source = evidence?.geometryMetadata?.source {
            values.append(source.reviewTitle)
        }
        if let anchor = spatialPlacement.anchorID ?? componentAttributes["geometryAnchorID"], !anchor.isEmpty {
            values.append("Anchor \(anchor)")
        }
        return Array(values.prefix(4))
    }
}

private extension SpatialCaptureState {
    var shortReviewTitle: String {
        switch self {
        case .anchored: return "Anchored"
        case .approximate: return "Approx"
        case .areaReferenceOnly: return "Area linked"
        case .failed: return "No geometry"
        case .unspecified: return "Spatial pending"
        }
    }
}

private extension GeometryCaptureMode {
    var reviewTitle: String {
        switch self {
        case .roomPlan: return "RoomPlan"
        case .focusPointCloud: return "Focus scan"
        case .photoOnly: return "Photo"
        case .manual: return "Marker"
        }
    }
}

private extension GeometrySource {
    var reviewTitle: String {
        switch self {
        case .roomPlan: return "RoomPlan"
        case .arkitSceneReconstruction: return "Scene mesh"
        case .arkitPointCloud: return "Point cloud"
        case .detectedBoundingBox: return "Measured"
        case .userMarked: return "User marked"
        }
    }
}

private func strongestConfidence(from values: [SpatialConfidence]) -> SpatialConfidence {
    if values.contains(.high) { return .high }
    if values.contains(.medium) { return .medium }
    if values.contains(.low) { return .low }
    return .unknown
}

struct CaptureReviewWorkspaceView: View {
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID
    var onResumeSurvey: (() -> Void)?

    @State private var areaReviewStates: [UUID: SuggestedAreaReviewState] = [:]
    @State private var areaNames: [UUID: String] = [:]
    @State private var areaMergeTargets: [UUID: UUID] = [:]
    @State private var areaAuditTrails: [UUID: [String]] = [:]
    @State private var objectReviewStates: [UUID: CaptureSuggestionReviewState] = [:]
    @State private var objectTitles: [UUID: String] = [:]
    @State private var specialObjectReviewStates: [UUID: CaptureSuggestionReviewState] = [:]
    @State private var suggestionReviewStates: [UUID: CaptureSuggestionReviewState] = [:]
    @State private var suggestionTitles: [UUID: String] = [:]
    @State private var activeSheet: CaptureReviewSheet?

    var body: some View {
        if let visit = viewModel.visit(id: visitID) {
            let cards = visit.captureReviewCards
            let areaObjectGroups = reviewedAreaObjectGroups(from: visit.areaObjectGroups)
            List {
                Section {
                    HStack {
                        Label(visit.captureReviewSummaryText, systemImage: "checklist.checked")
                        Spacer()
                        if visit.hasBlockingCaptureReviewItems {
                            Text("Attention needed")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red)
                        }
                    }
                } footer: {
                    Text("Review confirms Capture evidence before export or handoff. Suggestions are weak until confirmed or changed.")
                }

                Section("Property") {
                    LabeledContent("Reference", value: visit.propertyIdentity.reference)
                    if !visit.propertyIdentity.addressLine.isEmpty {
                        LabeledContent("Address", value: visit.propertyIdentity.addressLine)
                    }
                    if !visit.propertyIdentity.postcode.isEmpty {
                        LabeledContent("Postcode", value: visit.propertyIdentity.postcode)
                    }
                }

                Section("Working Twin") {
                    LabeledContent("ID", value: visit.workingTwin.id.uuidString)
                    LabeledContent("State", value: visit.workingTwin.repositoryState.title)
                    LabeledContent("Lifecycle", value: visit.workingTwin.lifecycleStage.title)
                    LabeledContent("Capture Session", value: visit.captureSession.id.uuidString)
                }

                Section("Areas") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This is what Daedalus thinks you captured.")
                            .font(.subheadline.weight(.semibold))
                        Text("Review the proposed property structure before reviewing individual evidence items.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    ForEach(areaObjectGroups) { group in
                        SuggestedAreaGroupCardView(
                            group: group,
                            mergeCandidates: areaObjectGroups.filter { $0.area.id != group.area.id && $0.area.reviewState != .merged },
                            onOpen: { activeSheet = .areaDetail(group.area) },
                            onConfirmArea: { updateArea(group.area, state: .confirmed) },
                            onRenameArea: { activeSheet = .renameArea(group.area) },
                            onMergeArea: { target in mergeArea(group.area, into: target.area) },
                            onIgnoreArea: { updateArea(group.area, state: .ignored) },
                            onMarkAreaUnresolved: { updateArea(group.area, state: .unresolved) },
                            onConfirmObject: { updateObject($0, state: .confirmed) },
                            onChangeObject: { activeSheet = .changeObject($0) },
                            onIgnoreObject: { updateObject($0, state: .ignored) },
                            onMarkObjectUnresolved: { updateObject($0, state: .unresolved) },
                            onConfirmSpecialObject: { updateSpecialObject($0, state: .confirmed) },
                            onIgnoreSpecialObject: { updateSpecialObject($0, state: .ignored) },
                            onMarkSpecialObjectUnresolved: { updateSpecialObject($0, state: .unresolved) }
                        )
                    }
                }

                Section("Objects") {
                    LabeledContent("Spatial objects", value: "\(visit.components.count)")
                    LabeledContent("Review objects", value: "\(areaObjectGroups.reduce(0) { $0 + $1.objects.count + $1.specialObjects.count })")
                }

                let geometrySummary = visit.captureGeometryReviewSummary
                if geometrySummary.hasGeometry {
                    Section("Geometry Review") {
                        GeometryReviewSummaryView(summary: geometrySummary)
                    }
                }

                if cards.isEmpty {
                    ContentUnavailableView("No capture evidence", systemImage: "tray")
                } else {
                    Section("Evidence") {
                        ForEach(cards) { card in
                            CaptureReviewCardView(
                                card: card,
                                thumbnailURL: card.photoFileName.flatMap { viewModel.evidenceFileURL(localFileName: $0) },
                                onExpandPhoto: { url in
                                    activeSheet = .expandedPhoto(
                                        ExpandedEvidencePhoto(
                                            id: card.evidenceID ?? card.id,
                                            title: card.objectName,
                                            url: url
                                        )
                                    )
                                },
                                onConfirm: {
                                    viewModel.setCaptureReviewDecision(
                                        .confirmed,
                                        componentID: card.componentID,
                                        visitID: visitID,
                                        reviewedLabel: card.suggestedLabel
                                    )
                                },
                                onChange: { activeSheet = .changeEvidence(card) },
                                onIgnore: {
                                    viewModel.setCaptureReviewDecision(.ignored, componentID: card.componentID, visitID: visitID)
                                },
                                onNeedsAttention: {
                                    viewModel.setCaptureReviewDecision(.needsAttention, componentID: card.componentID, visitID: visitID)
                                }
                            )
                        }
                    }
                }

                Section {
                    Button {
                        if let url = viewModel.makeReviewedExportTempURL(for: visitID) {
                            activeSheet = .share(url)
                        }
                    } label: {
                        Label("Create Reviewed Capture Package", systemImage: "shippingbox")
                    }
                    .disabled(cards.isEmpty || visit.hasBlockingCaptureReviewItems)
                } footer: {
                    Text("The package keeps raw evidence and review decisions. Confirmed or changed evidence is marked for reviewed handoff.")
                }
            }
            .navigationTitle("Review Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onResumeSurvey {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            onResumeSurvey()
                        } label: {
                            Label("Resume", systemImage: "figure.walk.motion")
                        }
                    }
                }
            }
            .onAppear {
                viewModel.refreshCaptureReviewSuggestions(for: visitID)
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .changeEvidence(let card):
                    CaptureReviewChangeSheet(card: card) { label in
                        viewModel.setCaptureReviewDecision(
                            .changed,
                            componentID: card.componentID,
                            visitID: visitID,
                            reviewedLabel: label
                        )
                    }
                case .areaDetail(let area):
                    if let group = areaObjectGroups.first(where: { $0.area.id == area.id }) {
                        SuggestedAreaDetailView(group: group)
                    }
                case .renameArea(let area):
                    SuggestedAreaRenameSheet(area: area) { name in
                        areaNames[area.id] = name
                        updateArea(area, state: .renamed)
                    }
                case .changeObject(let object):
                    AreaObjectChangeSheet(object: object) { label in
                        objectTitles[object.objectID] = label
                        updateObject(object, state: .changed)
                    }
                case .changeSuggestion(let suggestion):
                    CaptureSuggestionChangeSheet(suggestion: suggestion) { label in
                        suggestionTitles[suggestion.id] = label
                        updateSuggestion(suggestion, state: .changed)
                    }
                case .share(let url):
                    ActivityView(url: url)
                case .expandedPhoto(let photo):
                    ExpandedEvidencePhotoView(photo: photo)
                }
            }
        } else {
            ContentUnavailableView("Property not found", systemImage: "exclamationmark.triangle")
        }
    }

    private func reviewedAreaObjectGroups(from groups: [AreaObjectGroup]) -> [AreaObjectGroup] {
        var groupsByID = Dictionary(uniqueKeysWithValues: groups.map { group in
            var updated = group
            updated.area.name = areaNames[group.area.id] ?? group.area.name
            updated.area.reviewState = areaReviewStates[group.area.id] ?? group.area.reviewState
            updated.area.auditTrail += areaAuditTrails[group.area.id] ?? []
            updated.objects = group.objects.map { object in
                var updatedObject = object
                updatedObject.label = objectTitles[object.objectID] ?? object.label
                updatedObject.reviewState = objectReviewStates[object.objectID] ?? object.reviewState
                return updatedObject
            }
            updated.specialObjects = group.specialObjects.map { specialObject in
                var updatedSpecialObject = specialObject
                let key = specialObject.linkedComponentID ?? specialObject.id
                updatedSpecialObject.reviewState = specialObjectReviewStates[key] ?? specialObject.reviewState
                return updatedSpecialObject
            }
            return (updated.area.id, updated)
        })

        for (sourceID, targetID) in areaMergeTargets {
            guard var source = groupsByID[sourceID],
                  var target = groupsByID[targetID] else {
                continue
            }
            source.area.reviewState = .merged
            target.area.evidenceLinks.append(contentsOf: source.area.evidenceLinks)
            target.area.objectLinks.append(contentsOf: source.area.objectLinks)
            target.area.auditTrail.append(contentsOf: source.area.auditTrail)
            target.area.auditTrail.append("merged \(source.area.name) into \(target.area.name)")
            target.objects.append(contentsOf: source.objects)
            target.specialObjects.append(contentsOf: source.specialObjects)
            target.evidenceSummary.evidenceLinks.append(contentsOf: source.evidenceSummary.evidenceLinks)
            groupsByID[sourceID] = source
            groupsByID[targetID] = target
        }

        return groupsByID.values
            .filter { $0.area.reviewState != .merged }
            .sorted { $0.area.name.localizedStandardCompare($1.area.name) == .orderedAscending }
    }

    private func reviewedAreaGroups(from areaGroups: [SuggestedAreaGroup]) -> [SuggestedAreaGroup] {
        var groupsByID = Dictionary(uniqueKeysWithValues: areaGroups.map { area in
            var updated = area
            updated.name = areaNames[area.id] ?? area.name
            updated.reviewState = areaReviewStates[area.id] ?? area.reviewState
            updated.auditTrail += areaAuditTrails[area.id] ?? []
            return (updated.id, updated)
        })

        for (sourceID, targetID) in areaMergeTargets {
            guard var source = groupsByID[sourceID],
                  var target = groupsByID[targetID] else {
                continue
            }
            source.reviewState = .merged
            target.evidenceLinks.append(contentsOf: source.evidenceLinks)
            target.objectLinks.append(contentsOf: source.objectLinks)
            target.auditTrail.append(contentsOf: source.auditTrail)
            target.auditTrail.append("merged \(source.name) into \(target.name)")
            groupsByID[sourceID] = source
            groupsByID[targetID] = target
        }

        return groupsByID.values
            .filter { $0.reviewState != .merged }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func updateArea(_ area: SuggestedAreaGroup, state: SuggestedAreaReviewState) {
        areaReviewStates[area.id] = state
        areaAuditTrails[area.id, default: []].append("\(state.rawValue):\(Date().formatted(date: .omitted, time: .standard))")
    }

    private func mergeArea(_ area: SuggestedAreaGroup, into target: SuggestedAreaGroup) {
        areaMergeTargets[area.id] = target.id
        areaReviewStates[area.id] = .merged
        areaAuditTrails[area.id, default: []].append("merged into \(target.name)")
        areaAuditTrails[target.id, default: []].append("accepted merge from \(area.name)")
    }

    private func updateObject(_ object: AreaObjectReviewSummary, state: CaptureSuggestionReviewState) {
        objectReviewStates[object.objectID] = state
    }

    private func updateSpecialObject(_ specialObject: AreaSpecialObjectGroup, state: CaptureSuggestionReviewState) {
        specialObjectReviewStates[specialObject.linkedComponentID ?? specialObject.id] = state
    }

    private func reviewedSuggestions(from suggestions: [CaptureSuggestion]) -> [CaptureSuggestion] {
        suggestions.map { suggestion in
            var updated = suggestion
            updated.reviewState = suggestionReviewStates[suggestion.id] ?? suggestion.reviewState
            updated.title = suggestionTitles[suggestion.id] ?? suggestion.title
            return updated
        }
    }

    private func updateSuggestion(_ suggestion: CaptureSuggestion, state: CaptureSuggestionReviewState) {
        suggestionReviewStates[suggestion.id] = state
    }
}

private struct SuggestedAreaGroupCardView: View {
    let group: AreaObjectGroup
    let mergeCandidates: [AreaObjectGroup]
    let onOpen: () -> Void
    let onConfirmArea: () -> Void
    let onRenameArea: () -> Void
    let onMergeArea: (AreaObjectGroup) -> Void
    let onIgnoreArea: () -> Void
    let onMarkAreaUnresolved: () -> Void
    let onConfirmObject: (AreaObjectReviewSummary) -> Void
    let onChangeObject: (AreaObjectReviewSummary) -> Void
    let onIgnoreObject: (AreaObjectReviewSummary) -> Void
    let onMarkObjectUnresolved: (AreaObjectReviewSummary) -> Void
    let onConfirmSpecialObject: (AreaSpecialObjectGroup) -> Void
    let onIgnoreSpecialObject: (AreaSpecialObjectGroup) -> Void
    let onMarkSpecialObjectUnresolved: (AreaSpecialObjectGroup) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onOpen) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.area.name)
                            .font(.headline)
                        Text(group.area.category.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(group.area.reviewState.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(stateColor)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                Label("\(group.evidenceSummary.evidenceCount)", systemImage: "paperclip")
                Label("\(group.objects.count)", systemImage: "shippingbox")
                Label("\(group.specialObjects.count)", systemImage: "mappin.and.ellipse")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if group.objects.isEmpty && group.specialObjects.isEmpty {
                Text("Unresolved Objects")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(group.objects) { object in
                    AreaObjectRowView(
                        object: object,
                        onConfirm: { onConfirmObject(object) },
                        onChange: { onChangeObject(object) },
                        onIgnore: { onIgnoreObject(object) },
                        onMarkUnresolved: { onMarkObjectUnresolved(object) }
                    )
                }

                ForEach(group.specialObjects) { specialObject in
                    AreaSpecialObjectRowView(
                        specialObject: specialObject,
                        onConfirm: { onConfirmSpecialObject(specialObject) },
                        onIgnore: { onIgnoreSpecialObject(specialObject) },
                        onMarkUnresolved: { onMarkSpecialObjectUnresolved(specialObject) }
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ReviewActionButton(title: "Confirm", prominent: true, action: onConfirmArea)
                    ReviewActionButton(title: "Rename", action: onRenameArea)
                    Menu("Merge With...") {
                        ForEach(mergeCandidates) { candidate in
                            Button(candidate.area.name) { onMergeArea(candidate) }
                        }
                    }
                    .disabled(mergeCandidates.isEmpty)
                    ReviewActionButton(title: "Ignore", action: onIgnoreArea)
                    ReviewActionButton(title: "Unresolved", action: onMarkAreaUnresolved)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var stateColor: Color {
        switch group.area.reviewState {
        case .confirmed, .renamed:
            return .green
        case .merged, .ignored:
            return .secondary
        case .unresolved:
            return .red
        case .suggested:
            return .orange
        }
    }
}

private struct AreaObjectRowView: View {
    let object: AreaObjectReviewSummary
    let onConfirm: () -> Void
    let onChange: () -> Void
    let onIgnore: () -> Void
    let onMarkUnresolved: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(object.label, systemImage: "shippingbox")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(object.reviewState.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(stateColor)
            }
            HStack(spacing: 10) {
                Label("\(object.evidenceSummary.evidenceCount)", systemImage: "paperclip")
                ForEach(object.evidenceSummary.labels.prefix(2), id: \.self) { label in
                    Text(label)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ReviewActionButton(title: "Confirm", prominent: true, action: onConfirm)
                ReviewActionButton(title: "Change", action: onChange)
                ReviewActionButton(title: "Ignore", action: onIgnore)
                ReviewActionButton(title: "Unresolved", action: onMarkUnresolved)
            }
        }
        .padding(.leading, 10)
        .padding(.vertical, 6)
    }

    private var stateColor: Color {
        switch object.reviewState {
        case .confirmed, .changed:
            return .green
        case .ignored:
            return .secondary
        case .unresolved, .needsAttention:
            return .red
        case .suggested:
            return .orange
        }
    }
}

private struct AreaSpecialObjectRowView: View {
    let specialObject: AreaSpecialObjectGroup
    let onConfirm: () -> Void
    let onIgnore: () -> Void
    let onMarkUnresolved: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(specialObject.label, systemImage: "mappin.and.ellipse")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(specialObject.reviewState.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(stateColor)
            }
            Label("\(specialObject.evidenceSummary.evidenceCount)", systemImage: "paperclip")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ReviewActionButton(title: "Confirm", prominent: true, action: onConfirm)
                ReviewActionButton(title: "Ignore", action: onIgnore)
                ReviewActionButton(title: "Unresolved", action: onMarkUnresolved)
            }
        }
        .padding(.leading, 10)
        .padding(.vertical, 6)
    }

    private var stateColor: Color {
        switch specialObject.reviewState {
        case .confirmed, .changed:
            return .green
        case .ignored:
            return .secondary
        case .unresolved, .needsAttention:
            return .red
        case .suggested:
            return .orange
        }
    }
}

private struct SuggestedAreaDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let group: AreaObjectGroup

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Category", value: group.area.category.title)
                    LabeledContent("Evidence", value: "\(group.evidenceSummary.evidenceCount)")
                    LabeledContent("Objects", value: "\(group.objects.count)")
                    LabeledContent("Special Objects", value: "\(group.specialObjects.count)")
                    LabeledContent("Review State", value: group.area.reviewState.title)
                }

                Section("Objects") {
                    if group.objects.isEmpty {
                        Text("No contained objects")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(group.objects) { object in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(object.label)
                                Text("\(object.evidenceSummary.evidenceCount) evidence items")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Special Objects") {
                    if group.specialObjects.isEmpty {
                        Text("No special objects")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(group.specialObjects) { specialObject in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(specialObject.label)
                                Text("\(specialObject.evidenceSummary.evidenceCount) evidence items")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Evidence") {
                    if group.evidenceSummary.evidenceLinks.isEmpty {
                        Text("No contained evidence")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(group.evidenceSummary.evidenceLinks) { evidence in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(evidence.label)
                                Text(evidence.sourceDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !group.area.auditTrail.isEmpty {
                    Section("Audit Trail") {
                        ForEach(group.area.auditTrail, id: \.self) { entry in
                            Text(entry)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(group.area.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct SuggestedAreaRenameSheet: View {
    @Environment(\.dismiss) private var dismiss

    let area: SuggestedAreaGroup
    let onSave: (String) -> Void

    @State private var selectedName: String

    init(area: SuggestedAreaGroup, onSave: @escaping (String) -> Void) {
        self.area = area
        self.onSave = onSave
        _selectedName = State(initialValue: area.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Area Name") {
                    Picker("Name", selection: $selectedName) {
                        ForEach(Visit.allowedSuggestedAreaNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                }

                Section("Original Area") {
                    Text(area.name)
                    Text("\(area.evidenceCount) evidence, \(area.objectCount) objects")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Rename Area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(selectedName)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct AreaObjectChangeSheet: View {
    @Environment(\.dismiss) private var dismiss

    let object: AreaObjectReviewSummary
    let onSave: (String) -> Void

    @State private var label: String

    init(object: AreaObjectReviewSummary, onSave: @escaping (String) -> Void) {
        self.object = object
        self.onSave = onSave
        _label = State(initialValue: object.label)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Object") {
                    TextField("Label", text: $label)
                        .textInputAutocapitalization(.words)
                }

                Section("Supporting Evidence") {
                    LabeledContent("Evidence", value: "\(object.evidenceSummary.evidenceCount)")
                    ForEach(object.evidenceSummary.labels, id: \.self) { label in
                        Text(label)
                    }
                }
            }
            .navigationTitle("Change Object")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(label.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct CaptureSuggestionGroupView: View {
    let title: String
    let systemImage: String
    let suggestions: [CaptureSuggestion]
    let onConfirm: (CaptureSuggestion) -> Void
    let onChange: (CaptureSuggestion) -> Void
    let onIgnore: (CaptureSuggestion) -> Void
    let onMarkUnresolved: (CaptureSuggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            if suggestions.isEmpty {
                Text("No suggestions yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(suggestions) { suggestion in
                    CaptureSuggestionCardView(
                        suggestion: suggestion,
                        onConfirm: { onConfirm(suggestion) },
                        onChange: { onChange(suggestion) },
                        onIgnore: { onIgnore(suggestion) },
                        onMarkUnresolved: { onMarkUnresolved(suggestion) }
                    )
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct CaptureSuggestionCardView: View {
    let suggestion: CaptureSuggestion
    let onConfirm: () -> Void
    let onChange: () -> Void
    let onIgnore: () -> Void
    let onMarkUnresolved: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daedalus thinks this is:")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(suggestion.title)
                        .font(.headline)
                    if !suggestion.detail.isEmpty {
                        Text(suggestion.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(suggestion.reviewState.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(stateColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Evidence:")
                    .font(.caption.weight(.semibold))
                ForEach(suggestion.evidenceLabels, id: \.self) { label in
                    Label(label, systemImage: "paperclip")
                }
                ForEach(suggestion.sources, id: \.self) { source in
                    Label(source.title, systemImage: sourceSystemImage(source))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ReviewActionButton(title: "Confirm", prominent: true, action: onConfirm)
                ReviewActionButton(title: "Change", action: onChange)
                ReviewActionButton(title: "Ignore", action: onIgnore)
                ReviewActionButton(title: "Unresolved", action: onMarkUnresolved)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var stateColor: Color {
        switch suggestion.reviewState {
        case .confirmed, .changed:
            return .green
        case .ignored:
            return .secondary
        case .unresolved, .needsAttention:
            return .red
        case .suggested:
            return .orange
        }
    }

    private func sourceSystemImage(_ source: CaptureSuggestionSource) -> String {
        switch source {
        case .transcript:
            return "text.quote"
        case .spatialContext:
            return "location"
        case .manualTap:
            return "hand.tap"
        case .existingEvidence:
            return "doc.text"
        }
    }
}

private struct CaptureReviewCardView: View {
    let card: CaptureReviewCard
    let thumbnailURL: URL?
    let onExpandPhoto: (URL) -> Void
    let onConfirm: () -> Void
    let onChange: () -> Void
    let onIgnore: () -> Void
    let onNeedsAttention: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    if let thumbnailURL {
                        onExpandPhoto(thumbnailURL)
                    }
                } label: {
                    PhotoThumbnail(url: thumbnailURL, markerType: card.markerType)
                }
                .buttonStyle(.plain)
                .disabled(thumbnailURL == nil)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(card.evidenceType, systemImage: systemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(card.markerType == .safety ? .red : .primary)
                        Spacer()
                        ReviewChip(text: card.status?.title ?? ReviewStatus.unreviewed.title, color: statusColor)
                    }

                    Text(card.objectName)
                        .font(.headline)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(card.areaName) / \(card.markerType == .photo ? "Supporting photo" : card.markerType.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !card.transcriptExcerpt.isEmpty {
                        Text(card.transcriptExcerpt)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    } else {
                        Text("No transcript snippet available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    FlexibleChipRow(values: card.spatialMetadata + [card.capturedAt.formatted(date: .omitted, time: .shortened)])
                }
            }

            if card.photoFileName != nil {
                Label("Photo and spatial placement are reviewed as one evidence item.", systemImage: "paperclip")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !card.spatialMetadata.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Spatial metadata")
                        .font(.caption.weight(.semibold))
                    ForEach(card.spatialMetadata, id: \.self) { item in
                        Text(item)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            if card.requiresAttention {
                Label("Safety marker requires review before handoff", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ReviewActionButton(title: "Confirm", prominent: true, action: onConfirm)
                ReviewActionButton(title: "Change", action: onChange)
                ReviewActionButton(title: "Ignore", action: onIgnore)
                if card.markerType == .safety {
                    ReviewActionButton(title: "Attention", tint: .red, action: onNeedsAttention)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var systemImage: String {
        switch card.markerType {
        case .photo: return "photo"
        case .voice: return "waveform"
        case .mark: return "mappin.and.ellipse"
        case .safety: return "exclamationmark.triangle.fill"
        case .measurement: return "ruler"
        case .gas: return "flame.fill"
        case .water: return "drop.fill"
        case .electrical: return "bolt.fill"
        }
    }

    private var statusColor: Color {
        switch card.status {
        case .confirmed, .changed:
            return .green
        case .ignored:
            return .secondary
        case .needsAttention:
            return .red
        default:
            return .orange
        }
    }
}

private struct ReviewActionButton: View {
    let title: String
    var prominent = false
    var tint: Color?
    let action: () -> Void

    var body: some View {
        if prominent {
            Button(action: action) {
                label
            }
            .buttonStyle(.borderedProminent)
            .tint(tint)
        } else {
            Button(action: action) {
                label
            }
            .buttonStyle(.bordered)
            .tint(tint)
        }
    }

    private var label: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(maxWidth: .infinity, minHeight: 34)
    }
}

private struct ReviewChip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
    }
}

private struct FlexibleChipRow: View {
    let values: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                chips
            }
            VStack(alignment: .leading, spacing: 6) {
                chips
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var chips: some View {
        ForEach(values.filter { !$0.isEmpty }, id: \.self) { value in
            Text(value)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
        }
    }
}

private struct GeometryReviewSummaryView: View {
    let summary: CaptureGeometryReviewSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(summary.coverageStatus, systemImage: "cube.transparent")
                .font(.subheadline.weight(.semibold))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                GeometryMetricView(title: "Areas", value: "\(summary.areaCount)")
                GeometryMetricView(title: "Spatial evidence", value: "\(summary.spatialEvidenceCount)")
                GeometryMetricView(title: "Anchored", value: "\(summary.anchoredCount)")
                GeometryMetricView(title: "Approx", value: "\(summary.approximateCount)")
                GeometryMetricView(title: "RoomPlan", value: "\(summary.roomPlanCount)")
                GeometryMetricView(title: "Focus", value: "\(summary.focusCount)")
                GeometryMetricView(title: "Markers", value: "\(summary.manualCount)")
                GeometryMetricView(title: "Confidence", value: summary.confidence)
            }
            if !summary.anchors.isEmpty {
                FlexibleChipRow(values: Array(summary.anchors.prefix(4).map { "Anchor \($0)" }))
            }
        }
        .padding(.vertical, 6)
    }
}

private struct GeometryMetricView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }
}

private struct ExpandedEvidencePhotoView: View {
    @Environment(\.dismiss) private var dismiss
    let photo: ExpandedEvidencePhoto

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let image = UIImage(contentsOfFile: photo.url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding()
                } else {
                    ContentUnavailableView("Photo unavailable", systemImage: "photo")
                        .foregroundStyle(.white)
                }
            }
            .navigationTitle(photo.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct PhotoThumbnail: View {
    let url: URL?
    let markerType: LiveCaptureEvidenceKind

    var body: some View {
        Group {
            if let url,
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: placeholderSystemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(markerType == .safety ? .red : .secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.tertiarySystemGroupedBackground))
            }
        }
        .frame(width: 74, height: 74)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var placeholderSystemImage: String {
        switch markerType {
        case .photo:
            return "photo"
        case .voice:
            return "waveform"
        case .mark:
            return "mappin.and.ellipse"
        case .safety:
            return "exclamationmark.triangle.fill"
        case .measurement:
            return "ruler"
        case .gas:
            return "flame.fill"
        case .water:
            return "drop.fill"
        case .electrical:
            return "bolt.fill"
        }
    }
}

private struct CaptureSuggestionChangeSheet: View {
    @Environment(\.dismiss) private var dismiss

    let suggestion: CaptureSuggestion
    let onSave: (String) -> Void

    @State private var label: String

    init(suggestion: CaptureSuggestion, onSave: @escaping (String) -> Void) {
        self.suggestion = suggestion
        self.onSave = onSave
        _label = State(initialValue: suggestion.title)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Changed Suggestion") {
                    TextField("Label", text: $label)
                        .textInputAutocapitalization(.words)
                }

                Section("Original Suggestion") {
                    Text("Daedalus thinks this is:")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(suggestion.title)
                    if !suggestion.detail.isEmpty {
                        Text(suggestion.detail)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Change Suggestion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(label.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct CaptureReviewChangeSheet: View {
    @Environment(\.dismiss) private var dismiss

    let card: CaptureReviewCard
    let onSave: (String) -> Void

    @State private var label: String

    init(card: CaptureReviewCard, onSave: @escaping (String) -> Void) {
        self.card = card
        self.onSave = onSave
        _label = State(initialValue: card.reviewedLabel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reviewed Label") {
                    TextField("Label", text: $label)
                        .textInputAutocapitalization(.words)
                }

                Section("Original Suggestion") {
                    Text(card.suggestedLabel)
                    if !card.transcriptExcerpt.isEmpty {
                        Text(card.transcriptExcerpt)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Change Evidence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(label.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
