import Foundation

enum CaptureSessionStatus: Equatable {
    case pulled
    case capturing
    case hasUnreviewedEvidence
    case readyToMerge
    case merged

    var title: String {
        switch self {
        case .pulled: return "Pulled"
        case .capturing: return "Capturing"
        case .hasUnreviewedEvidence: return "Has unreviewed evidence"
        case .readyToMerge: return "Ready to merge"
        case .merged: return "Merged"
        }
    }

    var systemImage: String {
        switch self {
        case .pulled: return "arrow.down.circle"
        case .capturing: return "camera.viewfinder"
        case .hasUnreviewedEvidence: return "exclamationmark.circle"
        case .readyToMerge: return "checkmark.seal"
        case .merged: return "arrow.triangle.merge"
        }
    }
}

enum WorkingTwinWarningKind: Equatable, Identifiable {
    case leaveWithUncommittedEvidence
    case pullWouldReplaceLocalChanges
    case mergeWithUnreviewedEvidence

    var id: String {
        switch self {
        case .leaveWithUncommittedEvidence: return "leaveWithUncommittedEvidence"
        case .pullWouldReplaceLocalChanges: return "pullWouldReplaceLocalChanges"
        case .mergeWithUnreviewedEvidence: return "mergeWithUnreviewedEvidence"
        }
    }

    var title: String {
        switch self {
        case .leaveWithUncommittedEvidence: return "Uncommitted evidence"
        case .pullWouldReplaceLocalChanges: return "Local changes present"
        case .mergeWithUnreviewedEvidence: return "Evidence still needs review"
        }
    }

    var message: String {
        switch self {
        case .leaveWithUncommittedEvidence:
            return "This Working Twin contains captured evidence that has not been merged."
        case .pullWouldReplaceLocalChanges:
            return "Pulling the Property Twin may replace local captured evidence that has not been merged."
        case .mergeWithUnreviewedEvidence:
            return "Some captured evidence still needs review. Confirm the evidence or continue merge knowing those review states will be preserved."
        }
    }

    var confirmTitle: String {
        switch self {
        case .leaveWithUncommittedEvidence: return "Leave Working Twin"
        case .pullWouldReplaceLocalChanges: return "Pull Twin"
        case .mergeWithUnreviewedEvidence: return "Merge Twin"
        }
    }
}

enum PendingWorkingTwinAction: Equatable {
    case leave
    case pull
    case merge
}

struct PendingWorkingTwinWarning: Equatable, Identifiable {
    let visitID: UUID
    let kind: WorkingTwinWarningKind
    let action: PendingWorkingTwinAction

    var id: String { "\(visitID.uuidString)-\(kind.id)-\(action)" }
}

extension Visit {
    var captureSessionStatus: CaptureSessionStatus {
        if repositoryState == .merged || lifecycleStage == .merge {
            return .merged
        }
        if hasUnreviewedEvidence {
            return .hasUnreviewedEvidence
        }
        if repositoryState == .readyToMerge || lifecycleStage == .confirm {
            return .readyToMerge
        }
        if lifecycleStage == .pull || repositoryState == .localWorkingCopy {
            return .pulled
        }
        return .capturing
    }

    var hasUnreviewedEvidence: Bool {
        rooms.contains { room in
            room.evidence.contains { $0.reviewStatus == .needsReview }
        } ||
            components.contains { component in
                component.evidence.contains { $0.reviewStatus == .needsReview }
            }
    }

    var hasCapturedEvidence: Bool {
        rooms.contains { !$0.evidence.isEmpty } ||
            components.contains { !$0.evidence.isEmpty }
    }

    var hasUnmergedLocalWork: Bool {
        guard repositoryState != .merged else { return false }
        return repositoryState == .hasLocalChanges ||
            repositoryState == .stagedForReview ||
            repositoryState == .awaitingClarification ||
            repositoryState == .readyToMerge ||
            hasCapturedEvidence ||
            !components.isEmpty ||
            !relationships.isEmpty ||
            !waterSupplyObservations.isEmpty ||
            !servicePointObservations.isEmpty
    }

    var shouldWarnBeforeLeavingWorkingTwin: Bool {
        hasUnmergedLocalWork
    }

    var shouldWarnBeforePullingTwin: Bool {
        hasUnmergedLocalWork
    }

    var shouldWarnBeforeMerge: Bool {
        hasUnreviewedEvidence
    }
}
