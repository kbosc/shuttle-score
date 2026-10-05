import Foundation

/// Victoires et défaites.
public struct WinLoss: Equatable, Sendable {
    public var wins: Int
    public var losses: Int

    public init(wins: Int, losses: Int) {
        self.wins = wins
        self.losses = losses
    }

    /// Part de victoires, `nil` sans match terminé.
    public var winRate: Double? {
        wins + losses == 0 ? nil : Double(wins) / Double(wins + losses)
    }
}

/// Points gagnés sur un ensemble d'échanges (au service ou à la réception).
public struct PointRate: Equatable, Sendable {
    public var won: Int
    public var played: Int

    public init(won: Int, played: Int) {
        self.won = won
        self.played = played
    }

    /// `nil` sans aucun échange.
    public var rate: Double? { played == 0 ? nil : Double(won) / Double(played) }
}

/// Bilan d'un ensemble de matchs.
public struct StatsSummary: Equatable, Sendable {
    public let record: WinLoss
    /// Échanges servis par mon camp.
    public let serve: PointRate
    /// Échanges servis par le camp adverse.
    public let receive: PointRate
}

/// Victoires et défaites d'une semaine (du lundi au dimanche).
public struct WeekRecord: Equatable, Sendable {
    /// Lundi 00:00 de la semaine.
    public let weekStart: Date
    public let record: WinLoss

    public init(weekStart: Date, record: WinLoss) {
        self.weekStart = weekStart
        self.record = record
    }
}

/// Stats de l'iPhone, calculées à partir de l'historique (voir SPEC.md, « Stats »).
public struct MatchStats: Equatable, Sendable {
    public let overall: StatsSummary
    public let singles: StatsSummary
    public let doubles: StatsSummary
    /// Semaines où au moins un match a été terminé, de la plus ancienne à la plus récente.
    public let weeks: [WeekRecord]

    /// `calendar` : sert à découper les semaines (son fuseau horaire compte).
    public init(_ records: [MatchRecord], calendar: Calendar = .current) {
        overall = StatsSummary(records)
        singles = StatsSummary(records.filter { $0.match.format == .singles })
        doubles = StatsSummary(records.filter { $0.match.format == .doubles })

        // Semaines du lundi au dimanche, quelle que soit la région de l'appareil.
        var weekCalendar = calendar
        weekCalendar.firstWeekday = 2
        var byWeek: [Date: WinLoss] = [:]
        for record in records {
            guard let won = record.wonByMe,
                let week = weekCalendar.dateInterval(of: .weekOfYear, for: record.match.startedAt)
            else { continue }
            var tally = byWeek[week.start] ?? WinLoss(wins: 0, losses: 0)
            if won { tally.wins += 1 } else { tally.losses += 1 }
            byWeek[week.start] = tally
        }
        weeks = byWeek.sorted { $0.key < $1.key }
            .map { WeekRecord(weekStart: $0.key, record: $0.value) }
    }
}

extension StatsSummary {
    init(_ records: [MatchRecord]) {
        var record = WinLoss(wins: 0, losses: 0)
        var serve = PointRate(won: 0, played: 0)
        var receive = PointRate(won: 0, played: 0)
        for matchRecord in records {
            if let won = matchRecord.wonByMe {
                if won { record.wins += 1 } else { record.losses += 1 }
            }
            // Les points des matchs interrompus comptent aussi.
            for rally in matchRecord.match.rallyRecords {
                let wonRally = rally.winner == .me
                if rally.server.side == .me {
                    serve.played += 1
                    if wonRally { serve.won += 1 }
                } else {
                    receive.played += 1
                    if wonRally { receive.won += 1 }
                }
            }
        }
        self.init(record: record, serve: serve, receive: receive)
    }
}

extension MatchRecord {
    /// `true` gagné, `false` perdu, `nil` si le match n'est pas terminé.
    fileprivate var wonByMe: Bool? {
        guard status == .finished, let winner = match.state.winner else { return nil }
        return winner == .me
    }
}
