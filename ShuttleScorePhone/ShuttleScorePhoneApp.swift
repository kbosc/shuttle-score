import ShuttleCore
import ShuttleStore
import SwiftUI

@main
struct ShuttleScorePhoneApp: App {
    @State private var model = HistoryModel.make()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HistoryView(model: model)
            }
        }
    }
}

/// Historique affiché, rechargé à chaque match reçu de la montre.
@MainActor
@Observable
final class HistoryModel {
    private(set) var summaries: [MatchSummary] = []
    private(set) var stats = MatchStats([])
    private(set) var playerRecords: [PlayerRecord] = []
    /// Noms donnés aux joueurs, par match (sur l'iPhone seulement).
    private(set) var names: [UUID: [Player: String]] = [:]
    private(set) var records: [UUID: MatchRecord] = [:]
    /// Noms déjà utilisés : suggestions et orthographe de référence (le plus récent d'abord).
    var directory: PlayerDirectory {
        PlayerDirectory(summaries.compactMap { names[$0.id] })
    }
    private let store: (any HistorySource)?
    private var connectivity: PhoneConnectivity?

    init(store: (any HistorySource)?) {
        self.store = store
        reload()
    }

    func reload() {
        let history = (try? store?.history()) ?? []
        names = (try? store?.allNames()) ?? [:]
        records = Dictionary(uniqueKeysWithValues: history.map { ($0.match.id, $0) })
        summaries = history.map(MatchSummary.init)
        stats = MatchStats(history)
        playerRecords = MatchStats.byPlayer(history, names: names)
    }

    /// Enregistre les noms d'un match s'ils sont valides ; sinon renvoie la raison du refus.
    func saveNames(_ raw: [Player: String], forMatch id: UUID) -> NamingResult {
        guard let format = records[id]?.match.format else { return .valid([:]) }
        let result = PlayerDirectory.forEditing(
            id, namesNewestFirst: summaries.map { ($0.id, names[$0.id] ?? [:]) }
        ).naming(raw, in: format)
        if case .valid(let cleaned) = result {
            try? store?.setNames(cleaned, forMatch: id)
            reload()
        }
        return result
    }

    /// Supprime le match de l'iPhone seulement ; l'historique et les stats sont recalculés.
    func delete(matchID: UUID) {
        try? store?.delete(matchID: matchID)
        reload()
    }

    /// Stockage de l'app ; en tests UI, un stockage en mémoire, pré-rempli avec `-SeedHistory`.
    static func make() -> HistoryModel {
        let arguments = ProcessInfo.processInfo.arguments
        let store: SwiftDataMatchStore?
        if arguments.contains("-UITests") {
            store = try? SwiftDataMatchStore(inMemory: true)
            if arguments.contains("-SeedHistory"), let store { HistorySeed.insert(into: store) }
        } else {
            store = try? SwiftDataMatchStore()
        }
        let model = HistoryModel(store: store)
        if let store, !arguments.contains("-UITests") {
            model.connectivity = PhoneConnectivity(
                receiver: MatchSyncReceiver(store: store), onReceive: { model.reload() })
        }
        return model
    }
}

/// Ce dont l'historique a besoin du stockage (permet un stockage absent si SwiftData échoue).
@MainActor
protocol HistorySource: AnyObject {
    func history() throws -> [MatchRecord]
    func delete(matchID: UUID) throws
    func allNames() throws -> [UUID: [Player: String]]
    func setNames(_ names: [Player: String], forMatch id: UUID) throws
}

extension SwiftDataMatchStore: HistorySource {}

/// Matchs factices pour les tests UI de l'historique.
@MainActor
enum HistorySeed {
    static func insert(into store: SwiftDataMatchStore) {
        var won = Match(firstServer: .me, startedAt: Date(timeIntervalSince1970: 1_790_000_000))
        for _ in 0..<30 { won.recordRally(wonBy: .me) }
        // Double interrompu : set 1 gagné 15-10, set 2 entamé à 3-5.
        var interrupted = Match(
            doublesFirstService: .firstDoublesService(myTeamServer: .me),
            startedAt: Date(timeIntervalSince1970: 1_790_100_000))
        for _ in 0..<10 {
            interrupted.recordRally(wonBy: .me)
            interrupted.recordRally(wonBy: .opponent)
        }
        for _ in 0..<5 { interrupted.recordRally(wonBy: .me) }
        interrupted.chooseService(ServiceChoice(server: .me, receiver: .opponent1))
        for side: Side in [.me, .opponent, .me, .opponent, .me, .opponent, .opponent, .opponent] {
            interrupted.recordRally(wonBy: side)
        }
        try? store.save(MatchRecord(match: won, status: .finished))
        try? store.save(MatchRecord(match: interrupted, status: .interrupted))
    }
}
