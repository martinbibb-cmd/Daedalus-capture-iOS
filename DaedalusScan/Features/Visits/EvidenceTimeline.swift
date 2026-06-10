import Foundation

struct EvidenceTimelineEntry: Identifiable, Equatable {
    let id: UUID
    let capturedAt: Date
    let evidenceType: String
    let componentID: UUID?
    let componentTitle: String
    let spatialContext: String?
    let reviewStatus: ReviewStatus?
    let isMerged: Bool
}

extension Visit {
    var evidenceTimelineEntries: [EvidenceTimelineEntry] {
        evidenceTimelineEntries(componentID: nil)
    }

    func evidenceTimelineEntries(componentID requestedComponentID: UUID?) -> [EvidenceTimelineEntry] {
        let componentEntries = components
            .filter { component in
                requestedComponentID == nil || component.id == requestedComponentID
            }
            .flatMap { component in
                component.evidence.map { evidence in
                    EvidenceTimelineEntry(
                        id: evidence.id,
                        capturedAt: evidence.createdAt,
                        evidenceType: evidence.kind.title,
                        componentID: component.id,
                        componentTitle: component.canonicalSubtype.title,
                        spatialContext: component.spatialContext?.displaySummary,
                        reviewStatus: evidence.reviewStatus,
                        isMerged: repositoryState == .merged
                    )
                }
            }

        let roomEntries: [EvidenceTimelineEntry]
        if requestedComponentID == nil {
            roomEntries = rooms.flatMap { room in
                room.evidence.map { evidence in
                    EvidenceTimelineEntry(
                        id: evidence.id,
                        capturedAt: evidence.createdAt,
                        evidenceType: evidence.kind.title,
                        componentID: nil,
                        componentTitle: room.name,
                        spatialContext: room.spatialPlacement.anchorID,
                        reviewStatus: evidence.reviewStatus,
                        isMerged: repositoryState == .merged
                    )
                }
            }
        } else {
            roomEntries = []
        }

        return (componentEntries + roomEntries)
            .sorted { lhs, rhs in
                if lhs.capturedAt == rhs.capturedAt {
                    return lhs.componentTitle < rhs.componentTitle
                }
                return lhs.capturedAt > rhs.capturedAt
            }
    }
}
