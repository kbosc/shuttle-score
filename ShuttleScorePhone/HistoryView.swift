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
                    HistoryRow(summary: summary)
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
                StatsView(stats: model.stats)
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
            }
            Spacer()
            Text(resultLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(resultColor)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.row")
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
