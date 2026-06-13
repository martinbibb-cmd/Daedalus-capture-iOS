import XCTest
@testable import DaedalusScanCore

final class EvidenceTimelineTests: XCTestCase {
    func testTimelineSortsByTimestampNewestFirst() {
        let older = Date(timeIntervalSince1970: 100)
        let newer = Date(timeIntervalSince1970: 200)
        let visit = Visit(
            reference: "42 Elm Street",
            twinKind: .system,
            components: [
                component(evidence: [
                    Evidence(kind: .photo, localFileName: "older.jpg", createdAt: older),
                    Evidence(kind: .voiceNote, localFileName: "newer.txt", createdAt: newer)
                ])
            ]
        )

        XCTAssertEqual(visit.evidenceTimelineEntries.map(\.capturedAt), [newer, older])
    }

    func testTimelinePreservesSpatialContext() {
        let visit = Visit(
            reference: "42 Elm Street",
            twinKind: .system,
            components: [
                component(
                    evidence: [Evidence(kind: .photo, localFileName: "photo.jpg")],
                    spatialContext: SpatialEvidenceContext(
                        floorLevel: "Ground floor",
                        areaLabel: "Utility",
                        geometryID: "wall-east-01",
                        approximatePositionLabel: "Left of cylinder"
                    )
                )
            ]
        )

        XCTAssertEqual(
            visit.evidenceTimelineEntries.first?.spatialContext,
            "Ground floor / Utility / wall-east-01 / Left of cylinder"
        )
    }

    func testMergedEvidenceRemainsVisible() {
        let visit = Visit(
            reference: "42 Elm Street",
            twinKind: .system,
            components: [
                component(evidence: [Evidence(kind: .photo, localFileName: "photo.jpg", reviewStatus: .confirmed)])
            ],
            repositoryState: .merged,
            lifecycleStage: .merge,
            twinVersion: 2,
            lastMergedAt: Date()
        )

        let entry = visit.evidenceTimelineEntries.first
        XCTAssertEqual(visit.evidenceTimelineEntries.count, 1)
        XCTAssertEqual(entry?.reviewStatus, .confirmed)
        XCTAssertEqual(entry?.isMerged, true)
    }

    func testUnifiedTimelineCombinesVisitEventsChronologically() {
        let visitStart = Date(timeIntervalSince1970: 100)
        let photoTime = Date(timeIntervalSince1970: 120)
        let noteTime = Date(timeIntervalSince1970: 130)
        let recordingTime = Date(timeIntervalSince1970: 140)
        let transcriptTime = Date(timeIntervalSince1970: 150)
        let recording = VisitRecording(
            sequenceNumber: 1,
            localFileName: "recording-001.m4a",
            startedAt: recordingTime,
            status: .completed
        )
        let transcript = Transcript(
            source: TranscriptSource(recordingID: recording.id, localFileName: recording.localFileName),
            status: .complete,
            rawTranscript: "Cylinder noted.",
            createdAt: transcriptTime
        )
        let visit = Visit(
            reference: "42 Elm Street",
            createdAt: visitStart,
            twinKind: .system,
            rooms: [
                Room(name: "Kitchen")
            ],
            components: [
                component(evidence: [
                    Evidence(kind: .photo, localFileName: "photo.jpg", createdAt: photoTime),
                    Evidence(kind: .textNote, localFileName: "note.txt", createdAt: noteTime)
                ])
            ],
            recordings: [recording],
            transcripts: [transcript]
        )

        XCTAssertEqual(
            visit.unifiedTimelineEntries.map(\.kind),
            [.roomScan, .photo, .note, .recordingChunk, .transcript]
        )
        XCTAssertEqual(
            visit.unifiedTimelineEntries.map(\.capturedAt),
            [visitStart, photoTime, noteTime, recordingTime, transcriptTime]
        )
    }

    func testCaptureReviewWorkspaceGroupsRecordingsTranscriptsObservationsAndPhotos() {
        let visitStart = Date(timeIntervalSince1970: 100)
        let photoTime = Date(timeIntervalSince1970: 120)
        let noteTime = Date(timeIntervalSince1970: 130)
        let recordingTime = Date(timeIntervalSince1970: 140)
        let transcriptTime = Date(timeIntervalSince1970: 150)
        let recording = VisitRecording(
            sequenceNumber: 1,
            localFileName: "recording-001.m4a",
            startedAt: recordingTime,
            status: .completed
        )
        let transcript = Transcript(
            source: TranscriptSource(recordingID: recording.id, localFileName: recording.localFileName),
            status: .complete,
            rawTranscript: "Cylinder noted.",
            createdAt: transcriptTime
        )
        let visit = Visit(
            reference: "42 Elm Street",
            createdAt: visitStart,
            twinKind: .system,
            rooms: [
                Room(name: "Kitchen")
            ],
            components: [
                component(evidence: [
                    Evidence(kind: .photo, localFileName: "photo.jpg", createdAt: photoTime),
                    Evidence(kind: .textNote, localFileName: "note.txt", createdAt: noteTime)
                ])
            ],
            recordings: [recording],
            transcripts: [transcript]
        )

        let summary = visit.captureReviewWorkspaceSummary

        XCTAssertEqual(summary.recordings.map(\.title), ["Recording 001"])
        XCTAssertEqual(summary.transcripts.map(\.detail), ["Cylinder noted."])
        XCTAssertTrue(summary.observations.contains { $0.title == "Kitchen" })
        XCTAssertTrue(summary.observations.contains { $0.title == "Geometry" })
        XCTAssertEqual(summary.photos.map(\.title), ["Picture"])
        XCTAssertFalse(summary.isEmpty)
    }

    private func component(
        evidence: [Evidence],
        spatialContext: SpatialEvidenceContext = SpatialEvidenceContext(
            floorLevel: "Ground floor",
            areaLabel: "Utility",
            geometryID: nil,
            approximatePositionLabel: nil
        )
    ) -> SystemComponent {
        SystemComponent(
            kind: .boiler,
            canonicalSubtype: .combiBoiler,
            evidence: evidence,
            spatialContext: spatialContext
        )
    }
}
