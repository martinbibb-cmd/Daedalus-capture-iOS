import Foundation

public enum VisitImportConflictStrategy: Sendable {
    case replaceExistingVisit
    case keepBoth
}

public struct VisitImportMergeResult: Sendable {
    public let visits: [Visit]
    public let replacedVisits: [Visit]

    public init(visits: [Visit], replacedVisits: [Visit]) {
        self.visits = visits
        self.replacedVisits = replacedVisits
    }
}

public enum VisitImportMerger {
    public static func merge(
        existingVisits: [Visit],
        importedVisits: [Visit],
        strategy: VisitImportConflictStrategy
    ) -> VisitImportMergeResult {
        var visitsByID: [UUID: Visit] = Dictionary(uniqueKeysWithValues: existingVisits.map { ($0.id, $0) })
        var orderedVisitIDs = existingVisits.map(\.id)
        var reservedReferences = Set(existingVisits.map(\.reference))
        var replacedVisits: [Visit] = []

        for importedVisit in importedVisits {
            var candidate = importedVisit

            if let existing = visitsByID[importedVisit.id] {
                switch strategy {
                case .replaceExistingVisit:
                    if replacedVisits.contains(where: { $0.id == existing.id }) == false {
                        replacedVisits.append(existing)
                    }
                case .keepBoth:
                    let existingIDs = Set(visitsByID.keys)
                    let newID = makeUniqueVisitID(excluding: existingIDs)
                    let newReference = makeImportedReference(base: importedVisit.reference, reservedReferences: reservedReferences)
                    candidate = makeVisitCopy(from: importedVisit, id: newID, reference: newReference)
                }
            }

            if visitsByID[candidate.id] == nil {
                orderedVisitIDs.append(candidate.id)
            }
            visitsByID[candidate.id] = candidate
            reservedReferences.insert(candidate.reference)
        }

        return VisitImportMergeResult(
            visits: orderedVisitIDs.compactMap { visitsByID[$0] },
            replacedVisits: replacedVisits
        )
    }

    private static func makeUniqueVisitID(excluding ids: Set<UUID>) -> UUID {
        var candidate = UUID()
        while ids.contains(candidate) {
            candidate = UUID()
        }
        return candidate
    }

    private static func makeImportedReference(base: String, reservedReferences: Set<String>) -> String {
        guard reservedReferences.contains(base) else {
            return base
        }

        let suffix = "Imported copy"
        var candidate = "\(base) (\(suffix))"
        var count = 2
        while reservedReferences.contains(candidate) {
            candidate = "\(base) (\(suffix) \(count))"
            count += 1
        }
        return candidate
    }

    private static func makeVisitCopy(from visit: Visit, id: UUID, reference: String) -> Visit {
        Visit(
            id: id,
            reference: reference,
            createdAt: visit.createdAt,
            twinKind: visit.twinKind,
            customerName: visit.customerName,
            addressLine: visit.addressLine,
            postcode: visit.postcode,
            engineerName: visit.engineerName,
            appointmentDate: visit.appointmentDate,
            notes: visit.notes,
            currentSystemType: visit.currentSystemType,
            proposedSystemType: visit.proposedSystemType,
            captureMode: visit.captureMode,
            rooms: visit.rooms,
            components: visit.components,
            sectionStatuses: visit.sectionStatuses,
            proposedSectionStatuses: visit.proposedSectionStatuses
        )
    }
}
