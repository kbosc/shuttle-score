import Foundation
import ShuttleCore
import ShuttleStore
import SwiftData
import Testing

/// Copie du modèle tel qu'il était avant les noms des joueurs (même nom d'entité).
@Model
final class StoredMatch {
    @Attribute(.unique) var id: UUID
    var status: String
    var startedAt: Date
    var updatedAt: Date
    var format: String
    var players: [String]
    var payload: Data

    init(
        id: UUID, status: String, startedAt: Date, updatedAt: Date, format: String,
        players: [String], payload: Data
    ) {
        self.id = id
        self.status = status
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.format = format
        self.players = players
        self.payload = payload
    }
}

@MainActor
@Suite struct Migration {
    /// Les matchs déjà sur l'iPhone (ancien format) restent lisibles et nommables.
    @Test func matchesSavedBeforeTheNamesAreStillReadable() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shuttle-migration-\(UUID().uuidString).store")
        var match = Match(firstServer: .me)
        for _ in 0..<30 { match.recordRally(wonBy: .me) }
        do {
            let container = try ModelContainer(
                for: StoredMatch.self, configurations: ModelConfiguration(url: url))
            let context = ModelContext(container)
            context.insert(
                StoredMatch(
                    id: match.id, status: MatchStatus.finished.rawValue, startedAt: match.startedAt,
                    updatedAt: Date(), format: match.format.rawValue, players: ["me", "opponent1"],
                    payload: try JSONEncoder().encode(match)))
            try context.save()
        }

        let store = try SwiftDataMatchStore(url: url)
        #expect(try store.history().map(\.match.id) == [match.id])
        #expect(try store.names(forMatch: match.id).isEmpty)
        try store.setNames([.opponent1: "Lucas"], forMatch: match.id)
        #expect(try store.names(forMatch: match.id) == [.opponent1: "Lucas"])
    }
}
