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
            return CaptureReviewCard(
                id: component.id,
                componentID: component.id,
                evidenceID: primaryEvidence?.id,
                markerType: markerType,
                capturedAt: primaryEvidence?.createdAt ?? component.createdAtFallback,
                photoFileName: component.evidence.first(where: { $0.kind == .photo })?.localFileName,
                transcriptExcerpt: component.componentAttributes["transcriptSnippet"] ?? "",
                suggestedLabel: component.suggestedCaptureLabel,
                reviewedLabel: component.reviewedCaptureLabel,
                anchorStatus: component.spatialPlacement.captureState == .anchored ? "anchored" : "geometry pending",
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
}

private extension SystemComponent {
    var createdAtFallback: Date {
        evidence.map(\.createdAt).min() ?? Date()
    }
}

struct CaptureReviewWorkspaceView: View {
    @ObservedObject var viewModel: VisitListViewModel
    let visitID: UUID
    var onResumeSurvey: (() -> Void)?

    @State private var changeTarget: CaptureReviewCard?
    @State private var areaDetailTarget: SuggestedAreaGroup?
    @State private var areaRenameTarget: SuggestedAreaGroup?
    @State private var areaReviewStates: [UUID: SuggestedAreaReviewState] = [:]
    @State private var areaNames: [UUID: String] = [:]
    @State private var areaMergeTargets: [UUID: UUID] = [:]
    @State private var areaAuditTrails: [UUID: [String]] = [:]
    @State private var objectChangeTarget: AreaObjectReviewSummary?
    @State private var objectReviewStates: [UUID: CaptureSuggestionReviewState] = [:]
    @State private var objectTitles: [UUID: String] = [:]
    @State private var specialObjectReviewStates: [UUID: CaptureSuggestionReviewState] = [:]
    @State private var suggestionChangeTarget: CaptureSuggestion?
    @State private var suggestionReviewStates: [UUID: CaptureSuggestionReviewState] = [:]
    @State private var suggestionTitles: [UUID: String] = [:]
    @State private var isPresentingShareSheet = false
    @State private var shareURL: URL?

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
                            onOpen: { areaDetailTarget = group.area },
                            onConfirmArea: { updateArea(group.area, state: .confirmed) },
                            onRenameArea: { areaRenameTarget = group.area },
                            onMergeArea: { target in mergeArea(group.area, into: target.area) },
                            onIgnoreArea: { updateArea(group.area, state: .ignored) },
                            onMarkAreaUnresolved: { updateArea(group.area, state: .unresolved) },
                            onConfirmObject: { updateObject($0, state: .confirmed) },
                            onChangeObject: { objectChangeTarget = $0 },
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

                if cards.isEmpty {
                    ContentUnavailableView("No capture evidence", systemImage: "tray")
                } else {
                    Section("Evidence") {
                        ForEach(cards) { card in
                            CaptureReviewCardView(
                                card: card,
                                thumbnailURL: card.photoFileName.flatMap { viewModel.evidenceFileURL(localFileName: $0) },
                                onConfirm: {
                                    viewModel.setCaptureReviewDecision(
                                        .confirmed,
                                        componentID: card.componentID,
                                        visitID: visitID,
                                        reviewedLabel: card.suggestedLabel
                                    )
                                },
                                onChange: { changeTarget = card },
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
                            shareURL = url
                            isPresentingShareSheet = true
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
            .sheet(item: $changeTarget) { card in
                CaptureReviewChangeSheet(card: card) { label in
                    viewModel.setCaptureReviewDecision(
                        .changed,
                        componentID: card.componentID,
                        visitID: visitID,
                        reviewedLabel: label
                    )
                }
            }
            .sheet(item: $areaDetailTarget) { area in
                if let group = areaObjectGroups.first(where: { $0.area.id == area.id }) {
                    SuggestedAreaDetailView(group: group)
                }
            }
            .sheet(item: $areaRenameTarget) { area in
                SuggestedAreaRenameSheet(area: area) { name in
                    areaNames[area.id] = name
                    updateArea(area, state: .renamed)
                }
            }
            .sheet(item: $objectChangeTarget) { object in
                AreaObjectChangeSheet(object: object) { label in
                    objectTitles[object.objectID] = label
                    updateObject(object, state: .changed)
                }
            }
            .sheet(item: $suggestionChangeTarget) { suggestion in
                CaptureSuggestionChangeSheet(suggestion: suggestion) { label in
                    suggestionTitles[suggestion.id] = label
                    updateSuggestion(suggestion, state: .changed)
                }
            }
            .sheet(isPresented: $isPresentingShareSheet) {
                if let shareURL {
                    ActivityView(url: shareURL)
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
                HStack(spacing: 8) {
                    Button("Confirm", action: onConfirmArea)
                        .buttonStyle(.borderedProminent)
                    Button("Rename", action: onRenameArea)
                        .buttonStyle(.bordered)
                    Menu("Merge With...") {
                        ForEach(mergeCandidates) { candidate in
                            Button(candidate.area.name) { onMergeArea(candidate) }
                        }
                    }
                    .disabled(mergeCandidates.isEmpty)
                }
                HStack(spacing: 8) {
                    Button("Ignore", action: onIgnoreArea)
                        .buttonStyle(.bordered)
                    Button("Mark Unresolved", action: onMarkAreaUnresolved)
                        .buttonStyle(.bordered)
                }
            }
            .font(.caption.weight(.semibold))
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

            HStack(spacing: 8) {
                Button("Confirm", action: onConfirm)
                    .buttonStyle(.borderedProminent)
                Button("Change", action: onChange)
                    .buttonStyle(.bordered)
                Button("Ignore", action: onIgnore)
                    .buttonStyle(.bordered)
                Button("Mark Unresolved", action: onMarkUnresolved)
                    .buttonStyle(.bordered)
            }
            .font(.caption.weight(.semibold))
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

            HStack(spacing: 8) {
                Button("Confirm", action: onConfirm)
                    .buttonStyle(.borderedProminent)
                Button("Ignore", action: onIgnore)
                    .buttonStyle(.bordered)
                Button("Mark Unresolved", action: onMarkUnresolved)
                    .buttonStyle(.bordered)
            }
            .font(.caption.weight(.semibold))
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

            HStack(spacing: 8) {
                Button("Confirm", action: onConfirm)
                    .buttonStyle(.borderedProminent)
                Button("Change", action: onChange)
                    .buttonStyle(.bordered)
                Button("Ignore", action: onIgnore)
                    .buttonStyle(.bordered)
                Button("Mark Unresolved", action: onMarkUnresolved)
                    .buttonStyle(.bordered)
            }
            .font(.caption.weight(.semibold))
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
    let onConfirm: () -> Void
    let onChange: () -> Void
    let onIgnore: () -> Void
    let onNeedsAttention: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                PhotoThumbnail(url: thumbnailURL, markerType: card.markerType)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(card.markerType.title, systemImage: systemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(card.markerType == .safety ? .red : .primary)
                        Spacer()
                        Text(card.status?.title ?? ReviewStatus.unreviewed.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(statusColor)
                    }

                    Text(card.suggestedLabel)
                        .font(.headline)

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

                    HStack(spacing: 10) {
                        Label(card.anchorStatus, systemImage: "location")
                        Label(card.confidence, systemImage: "scope")
                        Text(card.capturedAt.formatted(date: .omitted, time: .shortened))
                            .monospacedDigit()
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }

            if card.requiresAttention {
                Label("Safety marker requires review before handoff", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }

            HStack(spacing: 8) {
                Button("Confirm", action: onConfirm)
                    .buttonStyle(.borderedProminent)
                Button("Change", action: onChange)
                    .buttonStyle(.bordered)
                Button("Ignore", action: onIgnore)
                    .buttonStyle(.bordered)
                if card.markerType == .safety {
                    Button("Needs attention", action: onNeedsAttention)
                        .buttonStyle(.bordered)
                        .tint(.red)
                }
            }
            .font(.caption.weight(.semibold))
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
