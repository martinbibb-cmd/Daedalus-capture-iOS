import Foundation

enum LiveCaptureEvidenceKind: String, CaseIterable {
    case photo
    case voice
    case mark
    case safety
    case measurement

    var title: String {
        switch self {
        case .photo: return "Photo"
        case .voice: return "Voice"
        case .mark: return "Focus"
        case .safety: return "Safety"
        case .measurement: return "Measurement"
        }
    }

    var evidenceNote: String {
        switch self {
        case .photo: return "Photo captured during live visit."
        case .voice: return "Voice note placeholder captured during live visit. Transcript pending."
        case .mark: return "Focus area captured during live visit."
        case .safety: return "Potential safety concern marked during live visit."
        case .measurement: return "Measurement captured during live visit."
        }
    }
}

enum CaptureReviewDecision: String, CaseIterable {
    case unreviewed
    case confirmed
    case changed
    case ignored
    case needsAttention

    var title: String {
        switch self {
        case .unreviewed: return "Unreviewed"
        case .confirmed: return "Confirmed"
        case .changed: return "Changed"
        case .ignored: return "Ignored"
        case .needsAttention: return "Needs attention"
        }
    }

    var reviewStatus: ReviewStatus {
        switch self {
        case .unreviewed: return .unreviewed
        case .confirmed: return .confirmed
        case .changed: return .changed
        case .ignored: return .ignored
        case .needsAttention: return .needsAttention
        }
    }

    var includedInReviewedHandoff: Bool {
        switch self {
        case .confirmed, .changed:
            return true
        case .unreviewed, .ignored, .needsAttention:
            return false
        }
    }
}

extension SystemComponent {
    var liveCaptureEvidenceKind: LiveCaptureEvidenceKind? {
        guard let rawValue = componentAttributes["liveEvidenceKind"] else { return nil }
        return LiveCaptureEvidenceKind(rawValue: rawValue)
    }

    var liveCaptureTitle: String {
        liveCaptureEvidenceKind?.title ?? canonicalSubtype.title
    }

    var isLiveCaptureEvidence: Bool {
        liveCaptureEvidenceKind != nil
    }

    var captureReviewDecision: CaptureReviewDecision {
        guard let rawValue = componentAttributes["reviewDecision"],
              let decision = CaptureReviewDecision(rawValue: rawValue) else {
            return .unreviewed
        }
        return decision
    }

    var suggestedCaptureLabel: String {
        nonEmpty(componentAttributes["suggestedLabel"]) ?? liveCaptureEvidenceKind?.defaultSuggestedLabel ?? liveCaptureTitle
    }

    var reviewedCaptureLabel: String {
        nonEmpty(componentAttributes["reviewedLabel"]) ?? suggestedCaptureLabel
    }

    var isIncludedInReviewedHandoff: Bool {
        captureReviewDecision.includedInReviewedHandoff
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

extension LiveCaptureEvidenceKind {
    var defaultSuggestedLabel: String {
        switch self {
        case .photo: return "Photo evidence"
        case .voice: return "Voice note"
        case .mark: return "Focus area"
        case .safety: return "Safety concern"
        case .measurement: return "Measurement"
        }
    }
}

extension Visit {
    var liveCaptureEvidenceComponents: [SystemComponent] {
        components.filter(\.isLiveCaptureEvidence)
    }

    var reviewedCaptureEvidenceComponents: [SystemComponent] {
        liveCaptureEvidenceComponents.filter(\.isIncludedInReviewedHandoff)
    }

    var ignoredCaptureEvidenceComponents: [SystemComponent] {
        liveCaptureEvidenceComponents.filter { $0.captureReviewDecision == .ignored }
    }

    var hasBlockingCaptureReviewItems: Bool {
        liveCaptureEvidenceComponents.contains { component in
            if component.liveCaptureEvidenceKind == .safety {
                return component.captureReviewDecision == .unreviewed || component.captureReviewDecision == .needsAttention
            }
            return component.captureReviewDecision == .needsAttention
        }
    }
}
