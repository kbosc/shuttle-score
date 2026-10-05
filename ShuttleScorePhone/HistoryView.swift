import ShuttleCore
import SwiftUI

/// Historique des matchs reçus de la montre, du plus récent au plus ancien.
struct HistoryView: View {
    let model: HistoryModel
    /// Match en attente de confirmation de suppression.
    @State private var pendingDeletion: MatchSummary?

    var body: some View {
        Group {
            if model.summaries.isEmpty {
                ContentUnavailableView(
                    "Aucun match", systemImage: "figure.badminton",
                    description: Text(
                        "Les matchs terminés ou arrêtés sur ta montre apparaîtront ici."))
            } else {
                List(model.summaries, id: \.id) { summary in
                    NavigationLink {
                        MatchDetailView(model: model, matchID: summary.id)
                    } label: {
                        HistoryRow(summary: summary, names: model.names[summary.id] ?? [:])
                    }
                    // Identifiant sur le lien (la ligne entière), pas sur son contenu :
                    // sinon chaque match est compté deux fois par les tests UI.
                    .accessibilityIdentifier("history.row")
                    .swipeActions(edge: .trailing) {
                        // Pas de rôle « destructive » : il retirerait la ligne avant
                        // la confirmation.
                        Button("Supprimer", systemImage: "trash") {
                            pendingDeletion = summary
                        }
                        .tint(.red)
                        .accessibilityIdentifier("history.delete")
                    }
                }
            }
        }
        .navigationTitle("Matchs")
        .confirmationDialog(
            "Supprimer ce match ?", isPresented: deletionIsPending, titleVisibility: .visible,
            presenting: pendingDeletion
        ) { summary in
            Button("Supprimer le match", role: .destructive) {
                model.delete(matchID: summary.id)
            }
            Button("Annuler", role: .cancel) {}
        } message: { _ in
            Text("Il disparaît de l'historique et des stats de l'iPhone.")
        }
        .toolbar {
            NavigationLink {
                StatsView(stats: model.stats, playerRecords: model.playerRecords)
            } label: {
                Label("Stats", systemImage: "chart.bar.xaxis")
            }
            .accessibilityIdentifier("history.stats")
        }
        .refreshable { model.reload() }
    }
}

extension HistoryView {
    private var deletionIsPending: Binding<Bool> {
        Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })
    }
}

private struct HistoryRow: View {
    let summary: MatchSummary
    let names: [Player: String]

    /// « avec Paul · contre Lucas, Marc », si des joueurs sont nommés.
    private var namesLine: String? {
        let partner = names[.partner].map { "avec \($0)" }
        let opponents = [names[.opponent1], names[.opponent2]].compactMap { $0 }
        let against = opponents.isEmpty ? nil : "contre \(opponents.joined(separator: ", "))"
        let line = [partner, against].compactMap { $0 }.joined(separator: " · ")
        return line.isEmpty ? nil : line
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(summary.format == .singles ? "Simple" : "Double")
                    .font(.headline)
                Text(summary.games.map { "\($0.me)–\($0.opponent)" }.joined(separator: " · "))
                    .font(.body.monospacedDigit())
                if let namesLine {
                    Text(namesLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(resultLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(resultColor)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var resultLabel: String {
        switch summary.result {
        case .won: "Gagné"
        case .lost: "Perdu"
        case .interrupted: "Interrompu"
        }
    }

    private var resultColor: Color {
        switch summary.result {
        case .won: .green
        case .lost: .red
        case .interrupted: .secondary
        }
    }
}
