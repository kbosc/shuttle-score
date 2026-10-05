import Foundation
import ShuttleCore
import SwiftData

/// Un match sauvegardé sur la montre. Le match complet (règles, service, journal horodaté)
/// est gardé en JSON ; les champs à côté servent à trier et filtrer sans le décoder.
@Model
final class StoredMatch {
    @Attribute(.unique) var id: UUID
    var status: String
    var startedAt: Date
    var updatedAt: Date
    var format: String
    /// Joueurs du match (rôles : me, partner, opponent1, opponent2).
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
public final class SwiftDataMatchStore: MatchStore {
    private let context: ModelContext

    /// `url` nil : stockage par défaut de l'app. `inMemory` : pour les tests.
    public init(url: URL? = nil, inMemory: Bool = false) throws {
        let configuration =
            if let url {
                ModelConfiguration(url: url)
            } else {
                ModelConfiguration(isStoredInMemoryOnly: inMemory)
            }
        let container = try ModelContainer(for: StoredMatch.self, configurations: configuration)
        context = ModelContext(container)
    }

    public func save(_ record: MatchRecord) throws {
        let match = record.match
        let payload = try JSONEncoder().encode(match)
        let players = Player.allCases.filter {
            match.format == .doubles || [.me, .opponent1].contains($0)
        }
        .map(\.rawValue)
        if let stored = try stored(id: match.id) {
            stored.status = record.status.rawValue
            stored.updatedAt = Date()
            stored.payload = payload
        } else {
            context.insert(
                StoredMatch(
                    id: match.id, status: record.status.rawValue, startedAt: match.startedAt,
                    updatedAt: Date(), format: match.format.rawValue, players: players,
                    payload: payload))
        }
        try context.save()
    }

    public func delete(matchID: UUID) throws {
        if let stored = try stored(id: matchID) {
            context.delete(stored)
            try context.save()
        }
    }

    public func latestInProgress() throws -> MatchRecord? {
        let inProgress = MatchStatus.inProgress.rawValue
        var descriptor = FetchDescriptor<StoredMatch>(
            predicate: #Predicate { $0.status == inProgress },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        guard let stored = try context.fetch(descriptor).first else { return nil }
        return MatchRecord(
            match: try JSONDecoder().decode(Match.self, from: stored.payload), status: .inProgress)
    }

    /// Historique : matchs terminés et interrompus, du plus récent au plus ancien.
    public func history() throws -> [MatchRecord] {
        let inProgress = MatchStatus.inProgress.rawValue
        let descriptor = FetchDescriptor<StoredMatch>(
            predicate: #Predicate { $0.status != inProgress },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        return try context.fetch(descriptor).compactMap { stored in
            guard let status = MatchStatus(rawValue: stored.status),
                let match = try? JSONDecoder().decode(Match.self, from: stored.payload)
            else { return nil }
            return MatchRecord(match: match, status: status)
        }
    }

    /// Efface tout (tests UI : chaque test démarre sans match sauvegardé).
    public func deleteAll() throws {
        try context.delete(model: StoredMatch.self)
        try context.save()
    }

    /// Nombre de matchs sauvegardés, tous statuts confondus.
    public func count() throws -> Int {
        try context.fetchCount(FetchDescriptor<StoredMatch>())
    }

    private func stored(id: UUID) throws -> StoredMatch? {
        var descriptor = FetchDescriptor<StoredMatch>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
