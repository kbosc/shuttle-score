import Foundation
import ShuttleCore

/// Stockage en mémoire partagé par les tests.
@MainActor
final class InMemoryStore: MatchStore {
    var records: [UUID: MatchRecord] = [:]
    var failsOnSave = false

    func save(_ record: MatchRecord) throws {
        if failsOnSave { throw CocoaError(.fileWriteUnknown) }
        records[record.match.id] = record
    }

    func delete(matchID: UUID) throws { records[matchID] = nil }

    func latestInProgress() throws -> MatchRecord? {
        records.values.filter { $0.status == .inProgress }
            .max { $0.match.startedAt < $1.match.startedAt }
    }
}
