import Charts
import ShuttleCore
import SwiftUI

/// Stats calculées sur l'historique (voir SPEC.md, « Stats »).
struct StatsView: View {
    let stats: MatchStats
    let playerRecords: [PlayerRecord]

    var body: some View {
        Group {
            if stats.overall.record.wins + stats.overall.record.losses == 0
                && stats.overall.serve.played + stats.overall.receive.played == 0
            {
                ContentUnavailableView(
                    "Pas encore de stats", systemImage: "chart.bar",
                    description: Text("Termine un match sur ta montre pour voir tes stats."))
            } else {
                List {
                    Section("Bilan") {
                        RecordTiles(record: stats.overall.record)
                    }
                    Section("Par semaine") {
                        WeeklyChart(weeks: stats.weeks)
                    }
                    Section("Points gagnés") {
                        RateRow(title: "Au service", rate: stats.overall.serve, id: "stats.serve")
                        RateRow(
                            title: "À la réception", rate: stats.overall.receive,
                            id: "stats.receive")
                    }
                    Section("Simple ou double") {
                        FormatChart(singles: stats.singles, doubles: stats.doubles)
                    }
                    Section {
                        if playerRecords.isEmpty {
                            Text("Nomme les joueurs d'un match depuis l'historique.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(playerRecords, id: \.name) { player in
                                PlayerRow(player: player)
                            }
                        }
                    } header: {
                        Text("Par joueur")
                    } footer: {
                        Text("Matchs terminés où le joueur est nommé.")
                    }
                }
            }
        }
        .navigationTitle("Stats")
    }
}

/// Bilan avec et contre une personne.
private struct PlayerRow: View {
    let player: PlayerRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(player.name).font(.headline)
            HStack {
                if player.with.wins + player.with.losses > 0 {
                    Text("avec \(player.with.wins) V – \(player.with.losses) D")
                }
                if player.against.wins + player.against.losses > 0 {
                    Text("contre \(player.against.wins) V – \(player.against.losses) D")
                }
            }
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("stats.player.\(player.name)")
    }
}

/// Victoires, défaites et part de victoires, en gros chiffres.
private struct RecordTiles: View {
    let record: WinLoss

    var body: some View {
        HStack {
            tile("Victoires", "\(record.wins)", id: "stats.wins", color: .green)
            tile("Défaites", "\(record.losses)", id: "stats.losses", color: .red)
            tile(
                "Réussite", record.winRate.map(percent) ?? "—", id: "stats.winRate", color: .primary
            )
        }
    }

    private func tile(_ title: String, _ value: String, id: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
                .accessibilityIdentifier(id)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Victoires et défaites empilées, une barre par semaine.
private struct WeeklyChart: View {
    let weeks: [WeekRecord]

    /// Étiquette de la semaine : son lundi (« 21 sept. »).
    private func label(_ week: WeekRecord) -> String {
        week.weekStart.formatted(.dateTime.day().month(.abbreviated))
    }

    var body: some View {
        if weeks.isEmpty {
            Text("Aucun match terminé pour l'instant.")
                .foregroundStyle(.secondary)
        } else {
            Chart {
                ForEach(weeks.suffix(12), id: \.weekStart) { week in
                    BarMark(
                        x: .value("Semaine", label(week)),
                        y: .value("Matchs", week.record.wins),
                        // Largeur fixe : une seule semaine ne doit pas remplir tout le graphique.
                        width: .fixed(28)
                    )
                    .foregroundStyle(by: .value("Résultat", "Victoires"))
                    BarMark(
                        x: .value("Semaine", label(week)),
                        y: .value("Matchs", week.record.losses),
                        width: .fixed(28)
                    )
                    .foregroundStyle(by: .value("Résultat", "Défaites"))
                }
            }
            .chartForegroundStyleScale(["Victoires": Color.green, "Défaites": Color.red])
            // Pas plus d'une barre par semaine à l'écran : les 12 dernières.
            .chartXScale(domain: weeks.suffix(12).map(label))
            .chartYAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
            .frame(height: 200)
            .padding(.vertical, 8)
        }
    }
}

private struct RateRow: View {
    let title: String
    let rate: PointRate
    let id: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(rate.won) / \(rate.played)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Text(rate.rate.map(percent) ?? "—")
                .font(.headline.monospacedDigit())
                .frame(minWidth: 56, alignment: .trailing)
                .accessibilityIdentifier(id)
        }
    }
}

/// Simple contre double : victoires, défaites, et points gagnés au service et à la réception.
private struct FormatChart: View {
    let singles: StatsSummary
    let doubles: StatsSummary

    private struct Bar: Identifiable {
        let format: String
        let measure: String
        let value: Double
        var id: String { format + measure }
    }

    /// Sans donnée, pas de barre : une barre à 0 % ferait croire à un échec total.
    private var bars: [Bar] {
        [("Simple", singles), ("Double", doubles)].flatMap { format, summary in
            [
                ("Réussite", summary.record.winRate), ("Service", summary.serve.rate),
                ("Réception", summary.receive.rate),
            ].compactMap { measure, value in
                value.map { Bar(format: format, measure: measure, value: $0) }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart(bars) { bar in
                BarMark(
                    x: .value("Mesure", bar.measure),
                    y: .value("Pourcentage", bar.value)
                )
                .foregroundStyle(by: .value("Format", bar.format))
                .position(by: .value("Format", bar.format))
            }
            .chartYScale(domain: 0...1)
            .chartXScale(domain: ["Réussite", "Service", "Réception"])
            .chartYAxis {
                AxisMarks(values: [0, 0.25, 0.5, 0.75, 1]) { value in
                    AxisGridLine()
                    AxisValueLabel { Text(percent(value.as(Double.self) ?? 0)) }
                }
            }
            .frame(height: 200)
            HStack {
                Text("Simple : \(singles.record.wins) V – \(singles.record.losses) D")
                Spacer()
                Text("Double : \(doubles.record.wins) V – \(doubles.record.losses) D")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

private func percent(_ value: Double) -> String {
    value.formatted(.percent.precision(.fractionLength(0)))
}

#Preview {
    NavigationStack { StatsView(stats: MatchStats([]), playerRecords: []) }
}
