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

enum LiveSpatialCapturePath: String, Codable, Hashable {
    case roomPlan
    case arkitFallback
    case focusPointCloud
}

enum LiveCaptureState: String, Codable, CaseIterable, Hashable {
    case idle
    case roomScanning
    case roomUnderstood
    case focusPreparing
    case focusCapturing
    case focusCaptured
    case focusEnding
    case error

    var isFocusActive: Bool {
        switch self {
        case .focusPreparing, .focusCapturing, .focusCaptured, .focusEnding:
            return true
        case .idle, .roomScanning, .roomUnderstood, .error:
            return false
        }
    }
}

enum MeasuredObjectType: String, Codable, CaseIterable, Identifiable, Hashable {
    case boiler
    case cylinder
    case radiator
    case gasMeter
    case electricMeter
    case control
    case pump
    case valve
    case cupboard
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .boiler: return "Boiler"
        case .cylinder: return "Cylinder"
        case .radiator: return "Radiator"
        case .gasMeter: return "Gas Meter"
        case .electricMeter: return "Electric Meter"
        case .control: return "Control"
        case .pump: return "Pump"
        case .valve: return "Valve"
        case .cupboard: return "Cupboard"
        case .other: return "Other"
        }
    }

    var componentSubtype: SystemComponentSubtype {
        switch self {
        case .boiler:
            return .unknownHeatSource
        case .cylinder:
            return .unventedCylinder
        case .radiator:
            return .radiatorUncontrolled
        case .gasMeter:
            return .gasMeter
        case .electricMeter:
            return .otherInfrastructure
        case .control:
            return .programmer
        case .pump:
            return .pump
        case .valve:
            return .zoneValve
        case .cupboard, .other:
            return .otherInfrastructure
        }
    }
}

struct EstimatedObjectDimensions: Codable, Hashable {
    var width: Double
    var height: Double
    var depth: Double
}

struct LiveSpatialScanProgress: Codable, Hashable {
    var meshAnchorCount: Int
    var planeAnchorCount: Int
    var roomElementCount: Int
    var lastAnchorID: String?
    var lastKnownPosition: SpatialPosition?
    var lastUpdatedAt: Date?
    var capturePath: LiveSpatialCapturePath

    init(
        meshAnchorCount: Int = 0,
        planeAnchorCount: Int = 0,
        roomElementCount: Int = 0,
        lastAnchorID: String? = nil,
        lastKnownPosition: SpatialPosition? = nil,
        lastUpdatedAt: Date? = nil,
        capturePath: LiveSpatialCapturePath = .roomPlan
    ) {
        self.meshAnchorCount = meshAnchorCount
        self.planeAnchorCount = planeAnchorCount
        self.roomElementCount = roomElementCount
        self.lastAnchorID = lastAnchorID
        self.lastKnownPosition = lastKnownPosition
        self.lastUpdatedAt = lastUpdatedAt
        self.capturePath = capturePath
    }

    static let empty = LiveSpatialScanProgress()

    var capturedSurfaceCount: Int {
        meshAnchorCount + planeAnchorCount
    }

    var hasGeometry: Bool {
        capturedSurfaceCount > 0 || roomElementCount > 0
    }

    var captureLabel: String {
        switch capturePath {
        case .roomPlan:
            if roomElementCount >= 4 || capturedSurfaceCount >= 4 {
                return "Room understood"
            }
            if hasGeometry {
                return "Building room outline"
            }
            return "Move around for more detail"
        case .arkitFallback:
            if capturedSurfaceCount >= 4 {
                return "Room understood"
            }
            if hasGeometry {
                return "Building room outline"
            }
            return "Needs another angle"
        case .focusPointCloud:
            if meshAnchorCount >= 2 {
                return "Local detail captured"
            }
            if hasGeometry {
                return "Capturing local detail"
            }
            return "Hold on the item"
        }
    }

    var confidence: SpatialConfidence {
        if roomElementCount >= 4 || meshAnchorCount >= 2 || capturedSurfaceCount >= 4 { return .high }
        if hasGeometry { return .medium }
        return .low
    }

    var placement: SpatialPlacement? {
        if let lastAnchorID, !lastAnchorID.isEmpty {
            return SpatialPlacement(
                anchorID: lastAnchorID,
                approximatePosition: lastKnownPosition,
                captureState: .anchored,
                confidence: confidence
            )
        }
        guard let lastKnownPosition else { return nil }
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
