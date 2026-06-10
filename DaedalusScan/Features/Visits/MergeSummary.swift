import Foundation

struct MergeSummary: Equatable {
    let currentVersion: Int
    let nextVersion: Int
    let addedComponents: Int
    let editedEvidence: Int
    let deletedEvidence: Int
    let confirmedEvidence: Int
    let needsReviewEvidence: Int

    var hasUnreviewedEvidence: Bool {
        needsReviewEvidence > 0
    }
}

extension Visit {
    var mergeSummary: MergeSummary {
        let componentEvidence = components.flatMap(\.evidence)
        let roomEvidence = rooms.flatMap(\.evidence)
        let evidence = componentEvidence + roomEvidence

        return MergeSummary(
            currentVersion: twinVersion,
            nextVersion: twinVersion + 1,
            addedComponents: components.count,
            editedEvidence: changeSetCounters["editedEvidence", default: 0],
            deletedEvidence: changeSetCounters["deletedEvidence", default: 0],
            confirmedEvidence: evidence.filter { $0.reviewStatus == .confirmed }.count,
            needsReviewEvidence: evidence.filter { $0.reviewStatus == .needsReview }.count
        )
    }
}
