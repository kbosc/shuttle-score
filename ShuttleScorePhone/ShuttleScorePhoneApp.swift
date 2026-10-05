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
    private let store: (any HistorySource)?
    private var connectivity: PhoneConnectivity?

    init(store: (any HistorySource)?) {
        self.store = store
        reload()
    }

    func reload() {
        let records = (try? store?.history()) ?? []
        summaries = records.map(MatchSummary.init)
        stats = MatchStats(records)
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
