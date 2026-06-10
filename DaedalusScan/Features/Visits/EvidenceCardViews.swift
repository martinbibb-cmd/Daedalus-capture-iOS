import SwiftUI

struct EvidenceCardView: View {
    let title: String
    let systemImage: String
    let detail: String
    let reviewStatus: ReviewStatus?
    let capturedAt: Date?
    var spatialContext: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(reviewStatus?.title ?? "Captured")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
            }

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let spatialContext, !spatialContext.isEmpty {
                Label(spatialContext, systemImage: "location")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let capturedAt {
                Text(capturedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var statusColor: Color {
        switch reviewStatus {
        case .confirmed:
            return .green
        case .needsReview:
            return .orange
        case .rejected:
            return .red
        case .draft, .none:
            return .secondary
        }
    }
}

extension EvidenceKind {
    var title: String {
        switch self {
        case .photo: return "Picture"
        case .voiceNote: return "Voice Note"
        case .textNote: return "Geometry"
        }
    }

    var systemImage: String {
        switch self {
        case .photo: return "photo"
        case .voiceNote: return "waveform"
        case .textNote: return "scope"
        }
    }
}

extension SpatialEvidenceContext {
    var displaySummary: String {
        [
            floorLevel,
            areaLabel,
            geometryID ?? "",
            approximatePositionLabel ?? ""
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: " / ")
    }

    var markerSummary: String {
        if let approximatePositionLabel,
           !approximatePositionLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return approximatePositionLabel
        }
        return areaLabel
    }
}
