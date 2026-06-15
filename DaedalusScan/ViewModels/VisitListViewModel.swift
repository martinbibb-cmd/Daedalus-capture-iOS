import Combine
import Foundation

@MainActor
public final class VisitListViewModel: ObservableObject {
    struct PendingImportConflict {
        let sourceURL: URL
        let conflictCount: Int
        let sampleReference: String
    }

    @Published private(set) var visits: [Visit] = []
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published private(set) var pendingImportConflict: PendingImportConflict?
    @Published private(set) var pendingWorkingTwinWarning: PendingWorkingTwinWarning?
    @Published private(set) var pendingCaptureRecoverySnapshot: CaptureRecoverySnapshot?

    private let repository: VisitRepository

    public init(repository: VisitRepository) {
        self.repository = repository
        loadVisits()
        loadCaptureRecoverySnapshot()
    }

    func loadVisits() {
        do {
            visits = try repository.loadVisits().sorted { $0.createdAt > $1.createdAt }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createVisit(
        reference: String,
        customerName: String = "",
        addressLine: String = "",
        postcode: String = "",
        engineerName: String? = nil,
        appointmentDate: Date? = nil,
        notes: String = "",
        currentSystemType: HeatingSystemType = .unknown,
        captureMode: CaptureMode = .create
    ) -> UUID? {
        let trimmedReference = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReference.isEmpty else {
            errorMessage = "Visit reference is required."
            return nil
        }

        let visit = Visit(
            reference: trimmedReference,
            twinKind: .system,
            customerName: customerName.trimmingCharacters(in: .whitespacesAndNewlines),
            addressLine: addressLine.trimmingCharacters(in: .whitespacesAndNewlines),
            postcode: postcode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            engineerName: normalizedOptionalString(engineerName ?? ""),
            appointmentDate: appointmentDate,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            currentSystemType: currentSystemType,
            captureMode: captureMode,
            repositoryState: .localWorkingCopy,
            lifecycleStage: .capture
        )
        visits.insert(
            visit,
            at: 0
        )
        persistChanges()
        return visit.id
    }

    func addRoom(to visitID: UUID, named name: String, placement: SpatialPlacement? = nil) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, let visitIndex = indexOfVisit(visitID) else {
            errorMessage = "Room name is required."
            return
        }

        visits[visitIndex].rooms.append(
            Room(
                name: trimmedName,
                spatialPlacement: placement ?? SpatialPlacement(captureState: .approximate, confidence: .low)
            )
        )
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func ensureScannedArea(in visitID: UUID) -> UUID? {
        guard let visitIndex = indexOfVisit(visitID) else { return nil }
        let nextIndex = visits[visitIndex].rooms.count + 1
        let room = Room(
            name: "Scanned Area \(nextIndex)",
            spatialPlacement: SpatialPlacement(captureState: .approximate, confidence: .low)
        )
        visits[visitIndex].rooms.append(room)
        markLocalChanges(at: visitIndex)
        persistChanges()
        return room.id
    }

    func visit(id: UUID) -> Visit? {
        visits.first { $0.id == id }
    }

    func loadCaptureRecoverySnapshot() {
        do {
            pendingCaptureRecoverySnapshot = try repository.loadCaptureRecoverySnapshot()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveCaptureRecoverySnapshot(_ snapshot: CaptureRecoverySnapshot) {
        do {
            try repository.saveCaptureRecoverySnapshot(snapshot)
            pendingCaptureRecoverySnapshot = snapshot
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearCaptureRecoverySnapshot() {
        do {
            try repository.clearCaptureRecoverySnapshot()
            pendingCaptureRecoverySnapshot = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func trackUnsavedEvidenceDraft(
        visitID: UUID,
        contextID: UUID? = nil,
        contextKind: CaptureRecoveryDraftContextKind = .visit,
        evidenceKind: EvidenceKind,
        localFileName: String? = nil,
        note: String = ""
    ) -> UUID? {
        guard visit(id: visitID) != nil else { return nil }
        var snapshot = pendingCaptureRecoverySnapshot ?? CaptureRecoverySnapshot(visitID: visitID)
        snapshot.visitID = visitID
        snapshot.unsavedEvidenceDrafts.append(
            RecoveredEvidenceDraft(
                visitID: visitID,
                contextID: contextID,
                contextKind: contextKind,
                evidenceKind: evidenceKind,
                localFileName: normalizedOptionalString(localFileName ?? ""),
                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
        snapshot.updatedAt = Date()
        saveCaptureRecoverySnapshot(snapshot)
        return snapshot.unsavedEvidenceDrafts.last?.id
    }

    func discardUnsavedEvidenceDraft(_ draftID: UUID) {
        guard var snapshot = pendingCaptureRecoverySnapshot else { return }
        snapshot.unsavedEvidenceDrafts.removeAll { $0.id == draftID }
        snapshot.updatedAt = Date()
        if snapshot.activeRecordingID == nil,
           snapshot.unsavedEvidenceDrafts.isEmpty,
           !snapshot.shouldOfferResumeRecording {
            clearCaptureRecoverySnapshot()
        } else {
            saveCaptureRecoverySnapshot(snapshot)
        }
    }

    func room(visitID: UUID, roomID: UUID) -> Room? {
        visit(id: visitID)?.rooms.first { $0.id == roomID }
    }

    func component(visitID: UUID, componentID: UUID) -> SystemComponent? {
        visit(id: visitID)?.components.first { $0.id == componentID }
    }

    func response(for questionKey: String, visitID: UUID, roomID: UUID) -> SurveyResponse {
        room(visitID: visitID, roomID: roomID)?.survey[questionKey] ?? SurveyResponse()
    }

    func updateResponse(_ response: SurveyResponse, for questionKey: String, visitID: UUID, roomID: UUID) {
        guard let visitIndex = indexOfVisit(visitID), let roomIndex = indexOfRoom(roomID, in: visitIndex) else {
            return
        }

        visits[visitIndex].rooms[roomIndex].survey[questionKey] = response
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func setRoomReviewStatus(_ status: ReviewStatus?, roomID: UUID, visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID), let roomIndex = indexOfRoom(roomID, in: visitIndex) else {
            return
        }
        visits[visitIndex].rooms[roomIndex].reviewStatus = status
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func setRoomReviewNotes(_ notes: String, roomID: UUID, visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID), let roomIndex = indexOfRoom(roomID, in: visitIndex) else {
            return
        }
        visits[visitIndex].rooms[roomIndex].reviewNotes = normalizedOptionalString(notes)
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func setRoomNotes(_ notes: String, roomID: UUID, visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID), let roomIndex = indexOfRoom(roomID, in: visitIndex) else {
            return
        }
        visits[visitIndex].rooms[roomIndex].notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func setCaptureMode(_ mode: CaptureMode, for visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID) else { return }
        visits[visitIndex].captureMode = mode
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func setCurrentSystemType(_ type: HeatingSystemType, for visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID) else { return }
        visits[visitIndex].currentSystemType = type
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func setVisitNotes(_ notes: String, for visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID) else { return }
        visits[visitIndex].notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func advanceLifecycle(_ stage: TwinLifecycleStage, for visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID) else { return }
        let previousStage = visits[visitIndex].lifecycleStage
        visits[visitIndex].lifecycleStage = stage
        visits[visitIndex].repositoryState = repositoryState(for: stage)
        if stage == .merge, previousStage != .merge {
            visits[visitIndex].twinVersion += 1
            visits[visitIndex].lastMergedAt = Date()
        }
        persistChanges()
    }

    func requestPullTwin(for visitID: UUID) {
        guard let visit = visit(id: visitID) else { return }
        guard visit.shouldWarnBeforePullingTwin else {
            advanceLifecycle(.pull, for: visitID)
            return
        }
        pendingWorkingTwinWarning = PendingWorkingTwinWarning(
            visitID: visitID,
            kind: .pullWouldReplaceLocalChanges,
            action: .pull
        )
    }

    func requestLeaveWorkingTwin(for visitID: UUID) -> Bool {
        guard let visit = visit(id: visitID) else { return true }
        guard visit.shouldWarnBeforeLeavingWorkingTwin else {
            return true
        }
        pendingWorkingTwinWarning = PendingWorkingTwinWarning(
            visitID: visitID,
            kind: .leaveWithUncommittedEvidence,
            action: .leave
        )
        return false
    }

    func requestMergeTwin(for visitID: UUID) {
        guard let visit = visit(id: visitID) else { return }
        guard visit.shouldWarnBeforeMerge else {
            advanceLifecycle(.merge, for: visitID)
            return
        }
        pendingWorkingTwinWarning = PendingWorkingTwinWarning(
            visitID: visitID,
            kind: .mergeWithUnreviewedEvidence,
            action: .merge
        )
    }

    func confirmPendingWorkingTwinWarning() {
        guard let warning = pendingWorkingTwinWarning else { return }
        pendingWorkingTwinWarning = nil
        switch warning.action {
        case .leave:
            break
        case .pull:
            advanceLifecycle(.pull, for: warning.visitID)
        case .merge:
            advanceLifecycle(.merge, for: warning.visitID)
        }
    }

    func cancelPendingWorkingTwinWarning() {
        pendingWorkingTwinWarning = nil
    }

    func confirmCapturedEvidence(for visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID) else { return }

        for roomIndex in visits[visitIndex].rooms.indices {
            for evidenceIndex in visits[visitIndex].rooms[roomIndex].evidence.indices
                where visits[visitIndex].rooms[roomIndex].evidence[evidenceIndex].reviewStatus == .needsReview {
                visits[visitIndex].rooms[roomIndex].evidence[evidenceIndex].reviewStatus = .confirmed
            }
        }

        for componentIndex in visits[visitIndex].components.indices {
            for evidenceIndex in visits[visitIndex].components[componentIndex].evidence.indices
                where visits[visitIndex].components[componentIndex].evidence[evidenceIndex].reviewStatus == .needsReview {
                visits[visitIndex].components[componentIndex].evidence[evidenceIndex].reviewStatus = .confirmed
            }
        }

        visits[visitIndex].lifecycleStage = .confirm
        visits[visitIndex].repositoryState = .readyToMerge
        persistChanges()
    }

    func sectionList(for visitID: UUID) -> [CaptureSection] {
        guard let visit = visit(id: visitID) else { return [] }
        return SystemComponentKind.captureSections(for: visit.currentSystemType)
    }

    func setSurveyResponseReviewStatus(
        _ status: ReviewStatus?,
        questionKey: String,
        roomID: UUID,
        visitID: UUID
    ) {
        guard let visitIndex = indexOfVisit(visitID), let roomIndex = indexOfRoom(roomID, in: visitIndex) else {
            return
        }
        guard var response = visits[visitIndex].rooms[roomIndex].survey[questionKey] else {
            return
        }
        response.reviewStatus = status
        visits[visitIndex].rooms[roomIndex].survey[questionKey] = response
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func setSurveyResponseReviewNotes(
        _ notes: String,
        questionKey: String,
        roomID: UUID,
        visitID: UUID
    ) {
        guard let visitIndex = indexOfVisit(visitID), let roomIndex = indexOfRoom(roomID, in: visitIndex) else {
            return
        }
        guard var response = visits[visitIndex].rooms[roomIndex].survey[questionKey] else {
            return
        }
        response.reviewNotes = normalizedOptionalString(notes)
        visits[visitIndex].rooms[roomIndex].survey[questionKey] = response
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func addComponent(
        to visitID: UUID,
        kind: SystemComponentKind,
        name: String,
        manufacturer: String,
        model: String,
        notes: String
    ) {
        guard let visitIndex = indexOfVisit(visitID) else {
            return
        }

        visits[visitIndex].components.append(
            SystemComponent(
                kind: kind,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                manufacturer: manufacturer.trimmingCharacters(in: .whitespacesAndNewlines),
                model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func attachPhoto(data: Data, to roomID: UUID, in visitID: UUID) {
        do {
            let url = try repository.makeEvidenceFileURL(fileExtension: "jpg", visitID: visitID, roomID: roomID)
            try data.write(to: url, options: .atomic)
            appendEvidence(Evidence(kind: .photo, localFileName: url.lastPathComponent), to: roomID, in: visitID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func attachPhoto(data: Data, toComponent componentID: UUID, in visitID: UUID) {
        do {
            let url = try repository.makeEvidenceFileURL(fileExtension: "jpg", visitID: visitID, componentID: componentID)
            try data.write(to: url, options: .atomic)
            appendEvidence(Evidence(kind: .photo, localFileName: url.lastPathComponent), toComponent: componentID, in: visitID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func prepareRoomVoiceNoteURL(for roomID: UUID, in visitID: UUID) -> URL? {
        do {
            return try repository.makeEvidenceFileURL(fileExtension: "m4a", visitID: visitID, roomID: roomID)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func prepareComponentVoiceNoteURL(for componentID: UUID, in visitID: UUID) -> URL? {
        do {
            return try repository.makeEvidenceFileURL(fileExtension: "m4a", visitID: visitID, componentID: componentID)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func attachVoiceNoteToRoom(from url: URL, to roomID: UUID, in visitID: UUID) {
        appendEvidence(Evidence(kind: .voiceNote, localFileName: url.lastPathComponent), to: roomID, in: visitID)
    }

    func attachVoiceNoteToComponent(from url: URL, to componentID: UUID, in visitID: UUID) {
        appendEvidence(Evidence(kind: .voiceNote, localFileName: url.lastPathComponent), toComponent: componentID, in: visitID)
    }

    func prepareVisitRecordingChunkURL(for visitID: UUID) -> (url: URL, sequenceNumber: Int)? {
        guard let visit = visit(id: visitID) else { return nil }
        let sequenceNumber = (visit.recordings.map(\.sequenceNumber).max() ?? 0) + 1
        do {
            let url = try repository.makeRecordingFileURL(visitID: visitID, sequenceNumber: sequenceNumber)
            return (url, sequenceNumber)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    @discardableResult
    func attachVisitRecordingChunk(
        localFileName: String,
        sequenceNumber: Int,
        startedAt: Date = Date(),
        status: VisitRecordingStatus = .recording,
        to visitID: UUID
    ) -> UUID? {
        guard let visitIndex = indexOfVisit(visitID) else { return nil }
        let recording = VisitRecording(
            sequenceNumber: sequenceNumber,
            localFileName: localFileName,
            startedAt: startedAt,
            status: status
        )
        visits[visitIndex].recordings.append(recording)
        markLocalChanges(at: visitIndex)
        persistChanges()
        return recording.id
    }

    func completeVisitRecordingChunk(
        recordingID: UUID,
        visitID: UUID,
        endedAt: Date = Date(),
        status: VisitRecordingStatus = .completed
    ) {
        guard let visitIndex = indexOfVisit(visitID),
              let recordingIndex = visits[visitIndex].recordings.firstIndex(where: { $0.id == recordingID }) else {
            return
        }
        let startedAt = visits[visitIndex].recordings[recordingIndex].startedAt
        visits[visitIndex].recordings[recordingIndex].endedAt = endedAt
        visits[visitIndex].recordings[recordingIndex].duration = max(0, endedAt.timeIntervalSince(startedAt))
        visits[visitIndex].recordings[recordingIndex].status = status
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    @discardableResult
    func attachTranscript(
        sourceRecordingID: UUID,
        status: TranscriptStatus = .pending,
        rawTranscript: String = "",
        chunks: [TranscriptChunk] = [],
        to visitID: UUID
    ) -> UUID? {
        guard let visitIndex = indexOfVisit(visitID),
              let recording = visits[visitIndex].recordings.first(where: { $0.id == sourceRecordingID }) else {
            return nil
        }
        let transcript = Transcript(
            source: TranscriptSource(
                recordingID: sourceRecordingID,
                localFileName: recording.localFileName
            ),
            status: status,
            rawTranscript: rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines),
            chunks: chunks
        )
        visits[visitIndex].transcripts.append(transcript)
        markLocalChanges(at: visitIndex)
        persistChanges()
        return transcript.id
    }

    func updateTranscript(
        transcriptID: UUID,
        visitID: UUID,
        status: TranscriptStatus,
        rawTranscript: String,
        chunks: [TranscriptChunk],
        failureReason: String? = nil
    ) {
        guard let visitIndex = indexOfVisit(visitID),
              let transcriptIndex = visits[visitIndex].transcripts.firstIndex(where: { $0.id == transcriptID }) else {
            return
        }
        visits[visitIndex].transcripts[transcriptIndex].status = status
        visits[visitIndex].transcripts[transcriptIndex].rawTranscript = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        visits[visitIndex].transcripts[transcriptIndex].chunks = chunks
        visits[visitIndex].transcripts[transcriptIndex].updatedAt = Date()
        visits[visitIndex].transcripts[transcriptIndex].failureReason = normalizedOptionalString(failureReason ?? "")
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func attachQuickEvidencePhoto(data: Data, toComponent componentID: UUID, in visitID: UUID) {
        do {
            let url = try repository.makeEvidenceFileURL(fileExtension: "jpg", visitID: visitID, componentID: componentID)
            try data.write(to: url, options: .atomic)
            appendEvidence(
                Evidence(
                    kind: .photo,
                    localFileName: url.lastPathComponent,
                    reviewStatus: .needsReview,
                    reviewNotes: "Picture captured from AR Capture."
                ),
                toComponent: componentID,
                in: visitID
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func attachVoiceTranscriptNote(_ transcript: String, toComponent componentID: UUID, in visitID: UUID) {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let url = try repository.makeEvidenceFileURL(fileExtension: "txt", visitID: visitID, componentID: componentID)
            try Data(trimmed.utf8).write(to: url, options: .atomic)
            appendEvidence(
                Evidence(
                    kind: .voiceNote,
                    localFileName: url.lastPathComponent,
                    reviewStatus: .needsReview,
                    reviewNotes: "Voice Note transcript captured from AR Capture."
                ),
                toComponent: componentID,
                in: visitID
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func attachTextNote(text: String, to roomID: UUID, in visitID: UUID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let url = try repository.makeEvidenceFileURL(fileExtension: "txt", visitID: visitID, roomID: roomID)
            try Data(trimmed.utf8).write(to: url, options: .atomic)
            appendEvidence(Evidence(kind: .textNote, localFileName: url.lastPathComponent), to: roomID, in: visitID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addAREvidenceCapture(
        to visitID: UUID,
        subtype: SystemComponentSubtype,
        areaID: UUID?,
        placement: SpatialPlacement?,
        photoData: Data?,
        voiceNoteText: String,
        includeGeometry: Bool,
        floorLevel: String,
        geometryID: String?,
        approximatePositionLabel: String?
    ) -> UUID? {
        guard let componentID = addSpatialObject(
            to: visitID,
            kind: subtype.legacyKind,
            subtype: subtype,
            areaID: areaID,
            placement: placement
        ) else {
            return nil
        }

        if let photoData {
            attachQuickEvidencePhoto(data: photoData, toComponent: componentID, in: visitID)
        }
        attachVoiceTranscriptNote(voiceNoteText, toComponent: componentID, in: visitID)

        if let visitIndex = indexOfVisit(visitID),
           let componentIndex = indexOfComponent(componentID, in: visitIndex) {
            visits[visitIndex].components[componentIndex].componentAttributes["componentTypeEvidence"] = subtype.title
            visits[visitIndex].components[componentIndex].componentAttributes["voiceNoteTranscript"] = normalizedOptionalString(voiceNoteText) ?? ""
            if photoData != nil {
                visits[visitIndex].components[componentIndex].componentAttributes["photoEvidenceLabel"] = "Picture captured from AR Capture."
            }
            let areaLabel: String
            if let areaID,
               let area = visits[visitIndex].areas.first(where: { $0.id == areaID }) {
                areaLabel = area.name
            } else {
                areaLabel = "Spatial capture"
            }
            visits[visitIndex].components[componentIndex].componentAttributes["areaEvidence"] = areaLabel
            visits[visitIndex].components[componentIndex].spatialContext = SpatialEvidenceContext(
                floorLevel: floorLevel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown level" : floorLevel.trimmingCharacters(in: .whitespacesAndNewlines),
                areaLabel: areaLabel,
                geometryID: normalizedOptionalString(geometryID ?? ""),
                approximatePositionLabel: normalizedOptionalString(approximatePositionLabel ?? "")
            )
            persistChanges()
        }

        if includeGeometry {
            if let visitIndex = indexOfVisit(visitID),
               let componentIndex = indexOfComponent(componentID, in: visitIndex) {
                visits[visitIndex].components[componentIndex].componentAttributes["geometryEvidence"] = "Selected geometry captured in AR Capture."
                persistChanges()
            }
            attachTextNoteToComponent(
                text: "Selected geometry captured in AR Capture. Confirm dimensions and anchor before merge.",
                to: componentID,
                in: visitID,
                reviewStatus: .needsReview,
                reviewNotes: "Geometry reference captured from AR Capture."
            )
        }
        return componentID
    }

    func addLiveCaptureEvidence(
        to visitID: UUID,
        kind: LiveCaptureEvidenceKind,
        placement: SpatialPlacement?,
        photoData: Data? = nil,
        recordingID: UUID? = nil,
        scanSessionID: UUID? = nil,
        cameraFrameReference: String? = nil,
        geometryAnchorID: String? = nil,
        positionLabel: String? = nil
    ) -> UUID? {
        guard let componentID = addSpatialObject(
            to: visitID,
            kind: .boiler,
            subtype: .unknownHeatSource,
            areaID: nil,
            placement: placement
        ) else {
            return nil
        }

        if kind == .voice {
            attachLiveVoicePlaceholder(toComponent: componentID, in: visitID)
        } else if let photoData {
            attachQuickEvidencePhoto(data: photoData, toComponent: componentID, in: visitID)
        } else {
            attachTextNoteToComponent(
                text: kind.evidenceNote,
                to: componentID,
                in: visitID,
                reviewStatus: kind == .safety ? .needsAttention : .unreviewed,
                reviewNotes: kind.title
            )
        }

        guard let visitIndex = indexOfVisit(visitID),
              let componentIndex = indexOfComponent(componentID, in: visitIndex) else {
            return componentID
        }

        var attributes = visits[visitIndex].components[componentIndex].componentAttributes
        attributes["captureSource"] = "Live Capture"
        attributes["liveEvidenceKind"] = kind.rawValue
        attributes["liveEvidenceTitle"] = kind.title
        attributes["capturePhase"] = "raw"
        attributes["reviewDecision"] = CaptureReviewDecision.unreviewed.rawValue
        attributes["suggestedLabel"] = kind.defaultSuggestedLabel
        attributes["reviewedLabel"] = ""
        if kind == .voice {
            attributes["transcriptSnippet"] = "Transcript pending."
            attributes["voiceNoteTranscript"] = "Transcript pending."
        }
        attributes["includedInReviewedHandoff"] = "false"
        attributes["reviewAuditTrail"] = "created:\(ISO8601DateFormatter().string(from: Date()))"
        attributes["capturedTimestamp"] = ISO8601DateFormatter().string(from: Date())
        attributes["recordingReference"] = recordingID?.uuidString ?? "current"
        attributes["scanSessionID"] = scanSessionID?.uuidString
        attributes["cameraFrameReference"] = normalizedOptionalString(cameraFrameReference ?? "")
        attributes["geometryAnchorID"] = normalizedOptionalString(geometryAnchorID ?? placement?.anchorID ?? "")
        attributes["positionLabel"] = normalizedOptionalString(positionLabel ?? "")
        visits[visitIndex].components[componentIndex].componentAttributes = attributes
        visits[visitIndex].components[componentIndex].name = kind.title
        visits[visitIndex].components[componentIndex].reviewStatus = kind == .safety ? .needsAttention : .unreviewed
        for evidenceIndex in visits[visitIndex].components[componentIndex].evidence.indices {
            visits[visitIndex].components[componentIndex].evidence[evidenceIndex].reviewStatus = kind == .safety ? .needsAttention : .unreviewed
        }
        visits[visitIndex].components[componentIndex].spatialContext = SpatialEvidenceContext(
            floorLevel: "Live capture",
            areaLabel: "Unclassified evidence",
            geometryID: attributes["geometryAnchorID"],
            approximatePositionLabel: attributes["positionLabel"]
        )
        persistChanges()

        return componentID
    }

    private func attachLiveVoicePlaceholder(toComponent componentID: UUID, in visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID),
              let componentIndex = indexOfComponent(componentID, in: visitIndex) else {
            return
        }

        let sequenceNumber = (visits[visitIndex].recordings.map(\.sequenceNumber).max() ?? 0) + 1
        let localFileName = [
            visitID.uuidString,
            componentID.uuidString,
            "voice-placeholder",
            String(format: "%03d", sequenceNumber)
        ].joined(separator: "-") + ".m4a"
        let recording = VisitRecording(
            sequenceNumber: sequenceNumber,
            localFileName: localFileName,
            status: .completed
        )
        let transcript = Transcript(
            source: TranscriptSource(
                recordingID: recording.id,
                localFileName: localFileName
            ),
            status: .pending,
            rawTranscript: ""
        )
        let evidence = Evidence(
            kind: .voiceNote,
            localFileName: localFileName,
            reviewStatus: .unreviewed,
            reviewNotes: "Voice note placeholder captured during live spatial session. Transcript pending.",
            transcriptReferences: [
                EvidenceTranscriptReference(
                    transcriptID: transcript.id,
                    sourceRecordingID: recording.id
                )
            ]
        )

        visits[visitIndex].recordings.append(recording)
        visits[visitIndex].transcripts.append(transcript)
        visits[visitIndex].components[componentIndex].evidence.insert(evidence, at: 0)
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func setCaptureReviewDecision(
        _ decision: CaptureReviewDecision,
        componentID: UUID,
        visitID: UUID,
        reviewedLabel: String? = nil
    ) {
        guard let visitIndex = indexOfVisit(visitID),
              let componentIndex = indexOfComponent(componentID, in: visitIndex) else {
            return
        }

        var attributes = visits[visitIndex].components[componentIndex].componentAttributes
        let suggestedLabel = normalizedOptionalString(attributes["suggestedLabel"] ?? "") ??
            visits[visitIndex].components[componentIndex].liveCaptureEvidenceKind?.defaultSuggestedLabel ??
            visits[visitIndex].components[componentIndex].liveCaptureTitle
        let finalLabel = normalizedOptionalString(reviewedLabel ?? "") ?? suggestedLabel
        attributes["suggestedLabel"] = suggestedLabel
        attributes["reviewedLabel"] = decision == .changed || decision == .confirmed ? finalLabel : normalizedOptionalString(reviewedLabel ?? "") ?? ""
        attributes["reviewDecision"] = decision.rawValue
        attributes["capturePhase"] = decision.includedInReviewedHandoff ? "reviewed" : "raw"
        attributes["includedInReviewedHandoff"] = decision.includedInReviewedHandoff ? "true" : "false"
        attributes["reviewedAt"] = ISO8601DateFormatter().string(from: Date())
        attributes["reviewAuditTrail"] = [
            normalizedOptionalString(attributes["reviewAuditTrail"] ?? ""),
            "\(decision.rawValue):\(ISO8601DateFormatter().string(from: Date())):\(finalLabel)"
        ]
        .compactMap { $0 }
        .joined(separator: " | ")

        visits[visitIndex].components[componentIndex].componentAttributes = attributes
        visits[visitIndex].components[componentIndex].reviewStatus = decision.reviewStatus
        for evidenceIndex in visits[visitIndex].components[componentIndex].evidence.indices {
            visits[visitIndex].components[componentIndex].evidence[evidenceIndex].reviewStatus = decision.reviewStatus
            visits[visitIndex].components[componentIndex].evidence[evidenceIndex].reviewNotes = finalLabel
        }
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func refreshCaptureReviewSuggestions(for visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID) else { return }
        let visit = visits[visitIndex]
        for componentIndex in visits[visitIndex].components.indices where visits[visitIndex].components[componentIndex].isLiveCaptureEvidence {
            guard visits[visitIndex].components[componentIndex].captureReviewDecision == .unreviewed ||
                    visits[visitIndex].components[componentIndex].captureReviewDecision == .needsAttention else {
                continue
            }
            let component = visits[visitIndex].components[componentIndex]
            let snippet = transcriptSnippet(near: component, in: visit)
            let suggestion = suggestedLabel(for: component, transcriptSnippet: snippet)
            visits[visitIndex].components[componentIndex].componentAttributes["suggestedLabel"] = suggestion
            visits[visitIndex].components[componentIndex].componentAttributes["transcriptSnippet"] = snippet
            if component.liveCaptureEvidenceKind == .safety {
                visits[visitIndex].components[componentIndex].componentAttributes["reviewDecision"] = CaptureReviewDecision.needsAttention.rawValue
                visits[visitIndex].components[componentIndex].reviewStatus = .needsAttention
                for evidenceIndex in visits[visitIndex].components[componentIndex].evidence.indices {
                    visits[visitIndex].components[componentIndex].evidence[evidenceIndex].reviewStatus = .needsAttention
                }
            }
        }
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func prepareReviewedCapturePackage(for visitID: UUID) -> Bool {
        guard let visitIndex = indexOfVisit(visitID) else { return false }
        guard !visits[visitIndex].hasBlockingCaptureReviewItems else {
            errorMessage = "Review safety and attention items before creating the reviewed capture package."
            return false
        }

        visits[visitIndex].changeSetCounters["rawCaptureEvidence"] = visits[visitIndex].liveCaptureEvidenceComponents.count
        visits[visitIndex].changeSetCounters["reviewedCaptureEvidence"] = visits[visitIndex].reviewedCaptureEvidenceComponents.count
        visits[visitIndex].changeSetCounters["ignoredCaptureEvidence"] = visits[visitIndex].ignoredCaptureEvidenceComponents.count
        markLocalChanges(at: visitIndex)
        persistChanges()
        return true
    }

    func makeReviewedExportTempURL(for visitID: UUID) -> URL? {
        guard prepareReviewedCapturePackage(for: visitID) else { return nil }
        return makeExportTempURL(for: visitID)
    }

    func evidenceFileURL(localFileName: String) -> URL? {
        repository.evidenceFileURL(localFileName: localFileName)
    }

    private func transcriptSnippet(near component: SystemComponent, in visit: Visit) -> String {
        let allText = visit.transcripts.flatMap { transcript in
            if transcript.chunks.isEmpty {
                return [transcript.rawTranscript]
            }
            return transcript.chunks.map(\.text)
        }
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }

        return allText.map { String($0.prefix(180)) } ?? ""
    }

    private func suggestedLabel(for component: SystemComponent, transcriptSnippet: String) -> String {
        let text = transcriptSnippet.lowercased()
        if text.contains("boiler") { return "Boiler" }
        if text.contains("flue") { return "Flue" }
        if text.contains("meter") { return "Meter" }
        if text.contains("radiator") { return "Radiator" }
        if text.contains("cylinder") || text.contains("tank") { return "Hot water cylinder" }
        if text.contains("valve") { return "Valve" }
        if text.contains("safety") || text.contains("concern") || text.contains("too close") { return "Safety concern" }
        return component.liveCaptureEvidenceKind?.defaultSuggestedLabel ?? component.liveCaptureTitle
    }

    func addCaptureLiteEvidenceCapture(
        to visitID: UUID,
        subtype: SystemComponentSubtype,
        areaID: UUID?,
        photoData: Data?,
        voiceNoteText: String,
        photoEvidenceLabel: String
    ) -> UUID? {
        let componentID = addAREvidenceCapture(
            to: visitID,
            subtype: subtype,
            areaID: areaID,
            placement: SpatialPlacement(captureState: .areaReferenceOnly, confidence: .low),
            photoData: photoData,
            voiceNoteText: voiceNoteText,
            includeGeometry: false,
            floorLevel: "Unknown level",
            geometryID: nil,
            approximatePositionLabel: nil
        )

        if let componentID,
           let visitIndex = indexOfVisit(visitID),
           let componentIndex = indexOfComponent(componentID, in: visitIndex) {
            visits[visitIndex].components[componentIndex].componentAttributes["captureSource"] = "Capture Lite"
            if !photoEvidenceLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                visits[visitIndex].components[componentIndex].componentAttributes["photoEvidenceLabel"] = photoEvidenceLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            persistChanges()
        }

        return componentID
    }

    func updateEvidenceBundle(
        componentID: UUID,
        visitID: UUID,
        subtype: SystemComponentSubtype,
        areaID: UUID?,
        geometryID: String,
        approximatePositionLabel: String,
        voiceNoteTranscript: String,
        photoEvidenceLabel: String
    ) {
        guard let visitIndex = indexOfVisit(visitID),
              let componentIndex = indexOfComponent(componentID, in: visitIndex) else {
            return
        }

        visits[visitIndex].components[componentIndex].kind = subtype.legacyKind
        visits[visitIndex].components[componentIndex].canonicalSubtype = subtype
        visits[visitIndex].components[componentIndex].componentAttributes["componentTypeEvidence"] = subtype.title
        visits[visitIndex].components[componentIndex].componentAttributes["voiceNoteTranscript"] = normalizedOptionalString(voiceNoteTranscript) ?? ""
        visits[visitIndex].components[componentIndex].componentAttributes["photoEvidenceLabel"] = normalizedOptionalString(photoEvidenceLabel) ?? ""

        let areaLabel: String
        if let areaID,
           let area = visits[visitIndex].areas.first(where: { $0.id == areaID }) {
            areaLabel = area.name
            applyAreaReference(toComponent: componentID, roomID: areaID, visitID: visitID, preserveExistingPlacement: true)
        } else {
            areaLabel = "Spatial capture"
            applyAreaReference(toComponent: componentID, roomID: nil, visitID: visitID, preserveExistingPlacement: true)
        }

        guard let refreshedVisitIndex = indexOfVisit(visitID),
              let refreshedComponentIndex = indexOfComponent(componentID, in: refreshedVisitIndex) else {
            return
        }

        visits[refreshedVisitIndex].components[refreshedComponentIndex].componentAttributes["areaEvidence"] = areaLabel
        let floorLevel = visits[refreshedVisitIndex].components[refreshedComponentIndex].spatialContext?.floorLevel ?? "Unknown level"
        visits[refreshedVisitIndex].components[refreshedComponentIndex].spatialContext = SpatialEvidenceContext(
            floorLevel: floorLevel,
            areaLabel: areaLabel,
            geometryID: normalizedOptionalString(geometryID),
            approximatePositionLabel: normalizedOptionalString(approximatePositionLabel)
        )

        if normalizedOptionalString(geometryID) != nil || normalizedOptionalString(approximatePositionLabel) != nil {
            visits[refreshedVisitIndex].components[refreshedComponentIndex].componentAttributes["geometryEvidence"] = "Selected geometry captured in AR Capture."
        } else {
            visits[refreshedVisitIndex].components[refreshedComponentIndex].componentAttributes.removeValue(forKey: "geometryEvidence")
        }

        markEvidenceBundleNeedsReview(componentIndex: refreshedComponentIndex, visitIndex: refreshedVisitIndex)
        incrementChangeSetCounter("editedEvidence", by: max(1, visits[refreshedVisitIndex].components[refreshedComponentIndex].evidence.count), visitIndex: refreshedVisitIndex)
        markLocalChanges(at: refreshedVisitIndex)
        persistChanges()
    }

    func linkTranscriptReferenceToRoomEvidence(
        _ reference: EvidenceTranscriptReference,
        evidenceID: UUID,
        roomID: UUID,
        visitID: UUID
    ) {
        guard let visitIndex = indexOfVisit(visitID),
              transcriptReferenceExists(reference, in: visits[visitIndex]),
              let roomIndex = indexOfRoom(roomID, in: visitIndex),
              let evidenceIndex = visits[visitIndex].rooms[roomIndex].evidence.firstIndex(where: { $0.id == evidenceID }) else {
            return
        }
        appendTranscriptReference(reference, to: &visits[visitIndex].rooms[roomIndex].evidence[evidenceIndex])
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func linkTranscriptReferenceToComponentEvidence(
        _ reference: EvidenceTranscriptReference,
        evidenceID: UUID,
        componentID: UUID,
        visitID: UUID
    ) {
        guard let visitIndex = indexOfVisit(visitID),
              transcriptReferenceExists(reference, in: visits[visitIndex]),
              let componentIndex = indexOfComponent(componentID, in: visitIndex),
              let evidenceIndex = visits[visitIndex].components[componentIndex].evidence.firstIndex(where: { $0.id == evidenceID }) else {
            return
        }
        appendTranscriptReference(reference, to: &visits[visitIndex].components[componentIndex].evidence[evidenceIndex])
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func deleteEvidenceBundle(componentID: UUID, visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID),
              let componentIndex = indexOfComponent(componentID, in: visitIndex) else {
            return
        }
        let component = visits[visitIndex].components[componentIndex]
        incrementChangeSetCounter("deletedEvidence", by: max(1, component.evidence.count), visitIndex: visitIndex)
        for evidence in component.evidence where !evidence.localFileName.isEmpty {
            repository.deleteEvidenceFile(named: evidence.localFileName)
        }
        visits[visitIndex].components.remove(at: componentIndex)
        visits[visitIndex].relationships.removeAll {
            $0.sourceComponentID == componentID || $0.targetComponentID == componentID
        }
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func attachTextNoteToComponent(
        text: String,
        to componentID: UUID,
        in visitID: UUID,
        reviewStatus: ReviewStatus? = nil,
        reviewNotes: String? = nil
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let url = try repository.makeEvidenceFileURL(fileExtension: "txt", visitID: visitID, componentID: componentID)
            try Data(trimmed.utf8).write(to: url, options: .atomic)
            appendEvidence(
                Evidence(
                    kind: .textNote,
                    localFileName: url.lastPathComponent,
                    reviewStatus: reviewStatus,
                    reviewNotes: reviewNotes
                ),
                toComponent: componentID,
                in: visitID
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setSectionStatus(_ status: SectionStatus, for kind: SystemComponentKind, visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID) else { return }
        visits[visitIndex].sectionStatuses[kind] = status
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func addSpatialObject(
        to visitID: UUID,
        kind: SystemComponentKind,
        subtype: SystemComponentSubtype? = nil,
        areaID: UUID?,
        placement: SpatialPlacement? = nil
    ) -> UUID? {
        guard let visitIndex = indexOfVisit(visitID) else { return nil }
        let captureMode = visits[visitIndex].captureMode
        let resolvedSubtype = subtype ?? kind.defaultSubtype
        let component = SystemComponent(
            kind: resolvedSubtype.legacyKind,
            captureMode: captureMode,
            canonicalSubtype: resolvedSubtype,
            spatialPlacement: placement ?? SpatialPlacement(captureState: .failed, confidence: .unknown)
        )
        visits[visitIndex].components.append(component)
        markLocalChanges(at: visitIndex)
        persistChanges()
        applyAreaReference(
            toComponent: component.id,
            roomID: areaID,
            visitID: visitID,
            preserveExistingPlacement: placement != nil
        )
        return component.id
    }

    func ensureComponent(for kind: SystemComponentKind, visitID: UUID) -> UUID? {
        guard let visitIndex = indexOfVisit(visitID) else { return nil }
        let captureMode = visits[visitIndex].captureMode
        if let existing = visits[visitIndex].components.first(where: { $0.kind == kind && $0.captureMode == captureMode }) {
            return existing.id
        }
        let component = SystemComponent(
            kind: kind,
            captureMode: captureMode,
            canonicalSubtype: kind.defaultSubtype,
            spatialPlacement: SpatialPlacement(captureState: .failed, confidence: .unknown)
        )
        visits[visitIndex].components.append(component)
        markLocalChanges(at: visitIndex)
        persistChanges()
        return component.id
    }

    func applyAreaReference(
        toComponent componentID: UUID,
        roomID: UUID?,
        visitID: UUID,
        preserveExistingPlacement: Bool = false
    ) {
        guard let visitIndex = indexOfVisit(visitID),
              let componentIndex = indexOfComponent(componentID, in: visitIndex) else {
            return
        }

        if let roomID,
           let roomIndex = indexOfRoom(roomID, in: visitIndex) {
            let room = visits[visitIndex].rooms[roomIndex]
            if !preserveExistingPlacement {
                visits[visitIndex].components[componentIndex].spatialPlacement = SpatialPlacement(
                    captureState: .areaReferenceOnly,
                    confidence: .low
                )
            }
            visits[visitIndex].components[componentIndex].componentAttributes["location"] = room.name
            upsertSpatialRelationship(
                visitIndex: visitIndex,
                sourceComponentID: componentID,
                relationship: .containedIn,
                targetComponentID: nil,
                targetAreaID: room.id
            )
        } else {
            if !preserveExistingPlacement {
                visits[visitIndex].components[componentIndex].spatialPlacement = SpatialPlacement(
                    captureState: .failed,
                    confidence: .unknown
                )
            }
            visits[visitIndex].components[componentIndex].componentAttributes.removeValue(forKey: "location")
            visits[visitIndex].relationships.removeAll {
                $0.sourceComponentID == componentID &&
                    $0.relationship == .containedIn &&
                    $0.targetAreaID != nil
            }
        }
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func relationships(for visitID: UUID, sourceComponentID: UUID) -> [SpatialRelationship] {
        guard let visit = visit(id: visitID) else { return [] }
        return visit.relationships.filter { $0.sourceComponentID == sourceComponentID }
    }

    func addRelationship(
        visitID: UUID,
        sourceComponentID: UUID,
        relationship: SpatialRelationshipType,
        targetComponentID: UUID?,
        targetAreaID: UUID?
    ) {
        guard let visitIndex = indexOfVisit(visitID),
              indexOfComponent(sourceComponentID, in: visitIndex) != nil else {
            return
        }
        upsertSpatialRelationship(
            visitIndex: visitIndex,
            sourceComponentID: sourceComponentID,
            relationship: relationship,
            targetComponentID: targetComponentID,
            targetAreaID: targetAreaID
        )
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func addWaterSupplyObservation(to visitID: UUID, observation: WaterSupplyObservation) {
        guard let visitIndex = indexOfVisit(visitID) else { return }
        visits[visitIndex].waterSupplyObservations.insert(observation, at: 0)
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func addServicePointObservation(to visitID: UUID, observation: ServicePointObservation) {
        guard let visitIndex = indexOfVisit(visitID) else { return }
        visits[visitIndex].servicePointObservations.insert(observation, at: 0)
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func removeRelationship(visitID: UUID, relationshipID: UUID) {
        guard let visitIndex = indexOfVisit(visitID) else { return }
        visits[visitIndex].relationships.removeAll { $0.id == relationshipID }
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func setSectionReviewLater(_ enabled: Bool, for kind: SystemComponentKind, visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID) else { return }
        let captureMode = visits[visitIndex].captureMode
        var didChange = false
        for index in visits[visitIndex].components.indices where
            visits[visitIndex].components[index].kind == kind &&
            visits[visitIndex].components[index].captureMode == captureMode {
            if enabled {
                if visits[visitIndex].components[index].reviewStatus == nil {
                    visits[visitIndex].components[index].reviewStatus = .needsReview
                    didChange = true
                }
            } else if visits[visitIndex].components[index].reviewStatus == .needsReview {
                visits[visitIndex].components[index].reviewStatus = nil
                didChange = true
            }
        }
        if didChange {
            markLocalChanges(at: visitIndex)
            persistChanges()
        }
    }

    func setComponentReviewStatus(_ status: ReviewStatus?, componentID: UUID, visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID),
              let componentIndex = indexOfComponent(componentID, in: visitIndex) else {
            return
        }
        visits[visitIndex].components[componentIndex].reviewStatus = status
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func setComponentReviewNotes(_ notes: String, componentID: UUID, visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID),
              let componentIndex = indexOfComponent(componentID, in: visitIndex) else {
            return
        }
        visits[visitIndex].components[componentIndex].reviewNotes = normalizedOptionalString(notes)
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func updateComponentAttribute(
        _ value: String,
        for key: String,
        componentID: UUID,
        visitID: UUID
    ) {
        guard let visitIndex = indexOfVisit(visitID),
              let componentIndex = indexOfComponent(componentID, in: visitIndex) else {
            return
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            visits[visitIndex].components[componentIndex].componentAttributes.removeValue(forKey: key)
        } else {
            visits[visitIndex].components[componentIndex].componentAttributes[key] = trimmed
        }
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func deleteVisit(id: UUID) {
        if let visit = visits.first(where: { $0.id == id }) {
            repository.deleteEvidenceFiles(for: visit)
        }
        visits.removeAll { $0.id == id }
        persistChanges()
    }

    func makeExportTempURL() -> URL? {
        do {
            let document = try VisitExportDocument(package: try repository.exportPackage(visits: visits))
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("DaedalusScanExport.daedalusscan")
            try document.data.write(to: url, options: .atomic)
            return url
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func makeExportTempURL(for visitID: UUID) -> URL? {
        guard let visit = visit(id: visitID) else { return nil }
        do {
            let document = try VisitExportDocument(package: try repository.exportPackage(visits: [visit]))
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("DaedalusScanExport_\(visit.reference).daedalusscan")
            try document.data.write(to: url, options: .atomic)
            return url
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func importPackage(from url: URL) {
        do {
            let conflicts = try repository.detectImportConflicts(from: url)
            guard conflicts.isEmpty else {
                pendingImportConflict = PendingImportConflict(
                    sourceURL: url,
                    conflictCount: conflicts.count,
                    sampleReference: conflicts[0].reference
                )
                return
            }

            completeImport(from: url, conflictResolution: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func replaceExistingVisitForPendingImport() {
        resolvePendingImport(with: .replaceExistingVisit)
    }

    func keepBothForPendingImport() {
        resolvePendingImport(with: .keepBoth)
    }

    func cancelPendingImport() {
        pendingImportConflict = nil
    }

    private func appendEvidence(_ evidence: Evidence, to roomID: UUID, in visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID), let roomIndex = indexOfRoom(roomID, in: visitIndex) else {
            return
        }

        visits[visitIndex].rooms[roomIndex].evidence.insert(evidence, at: 0)
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    private func appendEvidence(_ evidence: Evidence, toComponent componentID: UUID, in visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID),
              let componentIndex = indexOfComponent(componentID, in: visitIndex) else {
            return
        }

        visits[visitIndex].components[componentIndex].evidence.insert(evidence, at: 0)
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    private func markEvidenceBundleNeedsReview(componentIndex: Int, visitIndex: Int) {
        for evidenceIndex in visits[visitIndex].components[componentIndex].evidence.indices {
            visits[visitIndex].components[componentIndex].evidence[evidenceIndex].reviewStatus = .needsReview
        }
    }

    private func transcriptReferenceExists(_ reference: EvidenceTranscriptReference, in visit: Visit) -> Bool {
        guard let transcript = visit.transcripts.first(where: { $0.id == reference.transcriptID }) else {
            return false
        }
        if let sourceRecordingID = reference.sourceRecordingID,
           transcript.source.recordingID != sourceRecordingID {
            return false
        }
        if let chunkID = reference.chunkID,
           transcript.chunks.contains(where: { $0.id == chunkID }) == false {
            return false
        }
        return true
    }

    private func appendTranscriptReference(_ reference: EvidenceTranscriptReference, to evidence: inout Evidence) {
        if evidence.transcriptReferences.contains(reference) == false {
            evidence.transcriptReferences.append(reference)
        }
    }

    private func incrementChangeSetCounter(_ key: String, by amount: Int, visitIndex: Int) {
        guard amount > 0 else { return }
        visits[visitIndex].changeSetCounters[key, default: 0] += amount
    }

    func setRoomEvidenceReviewStatus(_ status: ReviewStatus?, evidenceID: UUID, roomID: UUID, visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID), let roomIndex = indexOfRoom(roomID, in: visitIndex) else {
            return
        }
        guard let evidenceIndex = visits[visitIndex].rooms[roomIndex].evidence.firstIndex(where: { $0.id == evidenceID }) else {
            return
        }
        visits[visitIndex].rooms[roomIndex].evidence[evidenceIndex].reviewStatus = status
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func setRoomEvidenceReviewNotes(_ notes: String, evidenceID: UUID, roomID: UUID, visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID), let roomIndex = indexOfRoom(roomID, in: visitIndex) else {
            return
        }
        guard let evidenceIndex = visits[visitIndex].rooms[roomIndex].evidence.firstIndex(where: { $0.id == evidenceID }) else {
            return
        }
        visits[visitIndex].rooms[roomIndex].evidence[evidenceIndex].reviewNotes = normalizedOptionalString(notes)
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func setComponentEvidenceReviewStatus(_ status: ReviewStatus?, evidenceID: UUID, componentID: UUID, visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID),
              let componentIndex = indexOfComponent(componentID, in: visitIndex) else {
            return
        }
        guard let evidenceIndex = visits[visitIndex].components[componentIndex].evidence.firstIndex(where: { $0.id == evidenceID }) else {
            return
        }
        visits[visitIndex].components[componentIndex].evidence[evidenceIndex].reviewStatus = status
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    func setComponentEvidenceReviewNotes(_ notes: String, evidenceID: UUID, componentID: UUID, visitID: UUID) {
        guard let visitIndex = indexOfVisit(visitID),
              let componentIndex = indexOfComponent(componentID, in: visitIndex) else {
            return
        }
        guard let evidenceIndex = visits[visitIndex].components[componentIndex].evidence.firstIndex(where: { $0.id == evidenceID }) else {
            return
        }
        visits[visitIndex].components[componentIndex].evidence[evidenceIndex].reviewNotes = normalizedOptionalString(notes)
        markLocalChanges(at: visitIndex)
        persistChanges()
    }

    private func indexOfVisit(_ visitID: UUID) -> Int? {
        visits.firstIndex { $0.id == visitID }
    }

    private func indexOfRoom(_ roomID: UUID, in visitIndex: Int) -> Int? {
        visits[visitIndex].rooms.firstIndex { $0.id == roomID }
    }

    private func indexOfComponent(_ componentID: UUID, in visitIndex: Int) -> Int? {
        visits[visitIndex].components.firstIndex { $0.id == componentID }
    }

    private func persistChanges() {
        do {
            try repository.save(visits: visits)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func markLocalChanges(at visitIndex: Int) {
        guard visits.indices.contains(visitIndex) else { return }
        switch visits[visitIndex].lifecycleStage {
        case .stage, .clarify, .confirm, .merge:
            break
        case .pull, .capture, .commit, .recapture:
            visits[visitIndex].lifecycleStage = .capture
        }

        if visits[visitIndex].repositoryState != .stagedForReview &&
            visits[visitIndex].repositoryState != .awaitingClarification &&
            visits[visitIndex].repositoryState != .readyToMerge {
            visits[visitIndex].repositoryState = .hasLocalChanges
        }
    }

    private func repositoryState(for stage: TwinLifecycleStage) -> TwinRepositoryState {
        switch stage {
        case .pull:
            return .localWorkingCopy
        case .capture, .commit, .recapture:
            return .hasLocalChanges
        case .stage:
            return .stagedForReview
        case .clarify:
            return .awaitingClarification
        case .confirm:
            return .readyToMerge
        case .merge:
            return .merged
        }
    }

    private func normalizedOptionalString(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func resolvePendingImport(with resolution: VisitImportConflictResolution) {
        guard let conflict = pendingImportConflict else { return }
        pendingImportConflict = nil
        completeImport(from: conflict.sourceURL, conflictResolution: resolution)
    }

    private func completeImport(from url: URL, conflictResolution: VisitImportConflictResolution?) {
        do {
            visits = try repository
                .importPackage(from: url, conflictResolution: conflictResolution)
                .sorted { $0.createdAt > $1.createdAt }
            statusMessage = "Import succeeded"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func upsertSpatialRelationship(
        visitIndex: Int,
        sourceComponentID: UUID,
        relationship: SpatialRelationshipType,
        targetComponentID: UUID?,
        targetAreaID: UUID?
    ) {
        if let index = visits[visitIndex].relationships.firstIndex(where: {
            $0.sourceComponentID == sourceComponentID && $0.relationship == relationship
        }) {
            visits[visitIndex].relationships[index].targetComponentID = targetComponentID
            visits[visitIndex].relationships[index].targetAreaID = targetAreaID
            return
        }
        visits[visitIndex].relationships.append(
            SpatialRelationship(
                sourceComponentID: sourceComponentID,
                relationship: relationship,
                targetComponentID: targetComponentID,
                targetAreaID: targetAreaID
            )
        )
    }
}
