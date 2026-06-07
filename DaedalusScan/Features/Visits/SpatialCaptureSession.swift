import Foundation

enum SpatialCaptureSessionStatus: String, Codable, CaseIterable, Hashable {
    case notStarted
    case scanning
    case paused
    case failed
    case completed

    var title: String {
        switch self {
        case .notStarted:
            return "Not Started"
        case .scanning:
            return "Scanning"
        case .paused:
            return "Paused"
        case .failed:
            return "Failed"
        case .completed:
            return "Completed"
        }
    }
}

struct CapturedAnchor: Identifiable, Codable, Hashable {
    var id: String
    var position: SpatialPosition?
    var confidence: SpatialConfidence
    var capturedAt: Date

    init(
        id: String = UUID().uuidString,
        position: SpatialPosition? = nil,
        confidence: SpatialConfidence = .medium,
        capturedAt: Date = Date()
    ) {
        self.id = id
        self.position = position
        self.confidence = confidence
        self.capturedAt = capturedAt
    }

    var placement: SpatialPlacement {
        SpatialPlacement(
            anchorID: id,
            approximatePosition: position,
            captureState: .anchored,
            confidence: confidence
        )
    }
}

struct LivePlacementState: Codable, Hashable {
    var currentAnchor: CapturedAnchor?
    var lastKnownPosition: SpatialPosition?
    var lastUpdatedAt: Date?

    static let unavailable = LivePlacementState()

    var hasAnchor: Bool {
        currentAnchor != nil
    }

    var currentPlacement: SpatialPlacement? {
        if let anchor = currentAnchor {
            return anchor.placement
        }
        guard let lastKnownPosition else {
            return nil
        }
        return SpatialPlacement(
            approximatePosition: lastKnownPosition,
            captureState: .approximate,
            confidence: .low
        )
    }
}

struct SpatialCaptureSession: Codable, Hashable, Identifiable {
    var id: UUID
    var status: SpatialCaptureSessionStatus
    var startedAt: Date?
    var endedAt: Date?

    init(
        id: UUID = UUID(),
        status: SpatialCaptureSessionStatus = .notStarted,
        startedAt: Date? = nil,
        endedAt: Date? = nil
    ) {
        self.id = id
        self.status = status
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}
