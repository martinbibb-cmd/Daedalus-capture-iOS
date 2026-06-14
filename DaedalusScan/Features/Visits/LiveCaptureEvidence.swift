import Foundation

enum LiveCaptureEvidenceKind: String, CaseIterable {
    case photo
    case mark
    case safety

    var title: String {
        switch self {
        case .photo: return "Photo"
        case .mark: return "Mark"
        case .safety: return "Safety"
        }
    }

    var evidenceNote: String {
        switch self {
        case .photo: return "Photo captured during live visit."
        case .mark: return "Marked as important during live visit."
        case .safety: return "Potential safety concern marked during live visit."
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
}
