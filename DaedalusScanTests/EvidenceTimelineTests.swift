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
