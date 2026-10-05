import ShuttleCore
import SwiftUI

/// Historique des matchs reçus de la montre, du plus récent au plus ancien.
struct HistoryView: View {
    let model: HistoryModel

    var body: some View {
        Group {
            if model.summaries.isEmpty {
                ContentUnavailableView(
                    "Aucun match", systemImage: "figure.badminton",
                    description: Text(
                        "Les matchs terminés ou arrêtés sur ta montre apparaîtront ici."))
            } else {
                List(Array(model.summaries.enumerated()), id: \.offset) { _, summary in
                    HistoryRow(summary: summary)
                }
            }
        }
        .navigationTitle("Matchs")
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
