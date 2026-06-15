import Foundation

enum ComponentMarkerFilter: String, CaseIterable, Identifiable {
    case all
    case needsReview
    case merged
    case unmerged

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .needsReview: return "Needs Review"
        case .merged: return "Merged"
        case .unmerged: return "Unmerged"
        }
    }
}

struct ComponentMarker: Identifiable, Equatable {
    let id: UUID
    let componentID: UUID
    let title: String
    let systemImage: String
    let areaLabel: String
    let positionLabel: String
    let reviewStatus: ReviewStatus?
    let isMerged: Bool

    var mergeStateTitle: String {
        isMerged ? "Merged" : "Unmerged"
    }
}

extension Visit {
    var componentMarkers: [ComponentMarker] {
        components.map { component in
            ComponentMarker(
                id: component.id,
                componentID: component.id,
                title: component.liveCaptureEvidenceKind?.title ?? component.canonicalSubtype.title,
                systemImage: component.canonicalCategory.markerSystemImage,
                areaLabel: component.spatialContext?.areaLabel ?? component.componentAttributes["location"] ?? "Spatial capture",
                positionLabel: component.spatialContext?.markerSummary ?? component.spatialPlacement.captureState.title,
                reviewStatus: component.evidenceBundleStatus ?? component.reviewStatus,
                isMerged: repositoryState == .merged
            )
        }
    }

    func componentMarkers(matching filter: ComponentMarkerFilter) -> [ComponentMarker] {
        componentMarkers.filter { marker in
            switch filter {
            case .all:
                return true
            case .needsReview:
                return marker.reviewStatus == .needsReview
            case .merged:
                return marker.isMerged
            case .unmerged:
                return !marker.isMerged
            }
        }
    }
}

private extension SystemComponentCategory {
    var markerSystemImage: String {
        switch self {
        case .heatSource: return "flame"
        case .hotWater: return "drop"
        case .emitter: return "radiator"
        case .control: return "slider.horizontal.3"
        case .infrastructure: return "wrench.and.screwdriver"
        case .unknown: return "cube"
        }
    }
}
