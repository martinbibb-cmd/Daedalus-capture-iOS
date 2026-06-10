import Foundation

struct CaptureReviewEvidenceCard: Equatable {
    let title: String
    let detail: String
    let reviewStatus: ReviewStatus?
    let capturedAt: Date?
    let spatialContext: String?
}

struct CaptureReviewEvidenceGroup: Identifiable, Equatable {
    let id: UUID
    let title: String
    let spatialContext: String?
    let cards: [CaptureReviewEvidenceCard]
}

extension Visit {
    var captureReviewEvidenceGroups: [CaptureReviewEvidenceGroup] {
        components.compactMap { component in
            let hasEvidenceCards = !component.evidence.isEmpty ||
                component.componentAttributes["componentTypeEvidence"] != nil ||
                component.componentAttributes["areaEvidence"] != nil ||
                component.componentAttributes["geometryEvidence"] != nil
            guard hasEvidenceCards else { return nil }

            let spatialContext = component.spatialContext?.displaySummary
            var cards = [
                CaptureReviewEvidenceCard(
                    title: "Component Type",
                    detail: component.componentAttributes["componentTypeEvidence"] ?? component.canonicalSubtype.title,
                    reviewStatus: component.evidenceBundleStatus,
                    capturedAt: nil,
                    spatialContext: spatialContext
                ),
                CaptureReviewEvidenceCard(
                    title: "Area / Location",
                    detail: component.componentAttributes["areaEvidence"] ?? component.componentAttributes["location"] ?? component.spatialPlacement.captureState.title,
                    reviewStatus: component.evidenceBundleStatus,
                    capturedAt: nil,
                    spatialContext: spatialContext
                )
            ]

            if let geometryEvidence = component.componentAttributes["geometryEvidence"] {
                cards.append(
                    CaptureReviewEvidenceCard(
                        title: "Geometry",
                        detail: geometryEvidence,
                        reviewStatus: component.evidenceBundleStatus,
                        capturedAt: nil,
                        spatialContext: spatialContext
                    )
                )
            }

            cards.append(
                contentsOf: component.evidence.map { evidence in
                    CaptureReviewEvidenceCard(
                        title: evidence.kind.title,
                        detail: component.displayDetail(for: evidence),
                        reviewStatus: evidence.reviewStatus,
                        capturedAt: evidence.createdAt,
                        spatialContext: spatialContext
                    )
                }
            )

            return CaptureReviewEvidenceGroup(
                id: component.id,
                title: component.spatialContext.map { "\(component.canonicalSubtype.title) - \($0.displaySummary)" } ?? component.canonicalSubtype.title,
                spatialContext: spatialContext,
                cards: cards
            )
        }
    }
}

extension SystemComponent {
    var evidenceBundleStatus: ReviewStatus? {
        guard !evidence.isEmpty else { return reviewStatus }
        if evidence.contains(where: { $0.reviewStatus == .needsReview }) {
            return .needsReview
        }
        if evidence.allSatisfy({ $0.reviewStatus == .confirmed }) {
            return .confirmed
        }
        return reviewStatus
    }

    func displayDetail(for evidence: Evidence) -> String {
        switch evidence.kind {
        case .photo:
            return componentAttributes["photoEvidenceLabel"].flatMap(nonEmpty) ?? evidence.localFileName
        case .voiceNote:
            return componentAttributes["voiceNoteTranscript"].flatMap(nonEmpty) ?? evidence.localFileName
        case .textNote:
            return componentAttributes["geometryEvidence"] ?? evidence.localFileName
        }
    }

    private func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
