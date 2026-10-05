import Foundation
import ShuttleCore
import Testing

private var utc: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

/// 2026-10-05, un lundi, à `hour` heures UTC, décalé de `days` jours.
private func date(days: Int = 0, hour: Int = 18) -> Date {
    utc.date(from: DateComponents(year: 2026, month: 10, day: 5 + days, hour: hour))!
}

private func singles(_ points: [Side], startedAt: Date = date(), firstServer: Side = .me)
    -> Match
{
    var match = Match(firstServer: firstServer, startedAt: startedAt)
    for side in points { match.recordRally(wonBy: side) }
    return match
}

private let straightWin = Array(repeating: Side.me, count: 30)
private let straightLoss = Array(repeating: Side.opponent, count: 30)

@Suite struct WinsAndLosses {
    @Test func onlyFinishedMatchesCount() {
        let stats = MatchStats(
            [
                MatchRecord(match: singles(straightWin), status: .finished),
                MatchRecord(match: singles(straightLoss), status: .finished),
                MatchRecord(match: singles(straightWin), status: .finished),
                MatchRecord(match: singles([.me, .me]), status: .interrupted),
            ], calendar: utc)
        #expect(stats.overall.record == WinLoss(wins: 2, losses: 1))
        #expect(stats.overall.record.winRate == 2.0 / 3.0)
    }

    @Test func noFinishedMatchMeansNoWinRate() {
        let stats = MatchStats(
            [MatchRecord(match: singles([.me]), status: .interrupted)], calendar: utc)
        #expect(stats.overall.record == WinLoss(wins: 0, losses: 0))
        #expect(stats.overall.record.winRate == nil)
    }
}

@Suite struct ServeAndReceive {
    @Test func pointsAreSplitByWhoServed() {
        // Je sers d'abord. Serveur avant chaque échange : moi, moi, moi, lui, lui.
        // Au service : 3 échanges, 2 gagnés. À la réception : 2 échanges, 1 gagné.
        let match = singles([.me, .me, .opponent, .opponent, .me])
        let stats = MatchStats([MatchRecord(match: match, status: .interrupted)], calendar: utc)
        #expect(stats.overall.serve == PointRate(won: 2, played: 3))
        #expect(stats.overall.receive == PointRate(won: 1, played: 2))
        #expect(stats.overall.serve.rate == 2.0 / 3.0)
    }

    @Test func pointsOfFinishedAndInterruptedMatchesBothCount() {
        // Terminé : 30 échanges, tous servis et gagnés par moi.
        // Interrompu : 3 servis par moi (2 gagnés), 2 reçus (1 gagné).
        let stats = MatchStats(
            [
                MatchRecord(match: singles(straightWin), status: .finished),
                MatchRecord(
                    match: singles([.me, .me, .opponent, .opponent, .me]), status: .interrupted),
            ], calendar: utc)
        #expect(stats.overall.serve == PointRate(won: 32, played: 33))
        #expect(stats.overall.receive == PointRate(won: 1, played: 2))
    }

    @Test func specExampleSixtyFivePercentOnServe() {
        // SPEC.md : 40 échanges servis par mon camp, 26 gagnés → 65 %.
        #expect(PointRate(won: 26, played: 40).rate == 0.65)
    }

    @Test func inDoublesMyWholeTeamCounts() {
        var match = Match(doublesFirstService: .firstDoublesService(myTeamServer: .me))
        // Échange 1 : je sers et gagne. 2 : je sers et perds. 3 : l'adversaire sert et perd.
        // 4 : mon camp sert et gagne. Au service : 3 échanges, 2 gagnés ; à la réception : 1 sur 1.
        for side: Side in [.me, .opponent, .me, .me] { match.recordRally(wonBy: side) }
        let stats = MatchStats([MatchRecord(match: match, status: .interrupted)], calendar: utc)
        #expect(stats.overall.serve == PointRate(won: 2, played: 3))
        #expect(stats.overall.receive == PointRate(won: 1, played: 1))
    }

    @Test func noRallyMeansNoRate() {
        #expect(MatchStats([], calendar: utc).overall.serve.rate == nil)
    }
}

@Suite struct Formats {
    @Test func singlesAndDoublesAreSeparated() {
        var doublesWin = Match(doublesFirstService: .firstDoublesService(myTeamServer: .me))
        for _ in 0..<15 { doublesWin.recordRally(wonBy: .me) }
        // En double, le set 2 attend le choix du service.
        doublesWin.chooseService(.firstDoublesService(myTeamServer: .partner))
        for _ in 0..<15 { doublesWin.recordRally(wonBy: .me) }
        let stats = MatchStats(
            [
                MatchRecord(match: singles(straightLoss), status: .finished),
                MatchRecord(match: doublesWin, status: .finished),
            ], calendar: utc)
        #expect(stats.singles.record == WinLoss(wins: 0, losses: 1))
        #expect(stats.doubles.record == WinLoss(wins: 1, losses: 0))
        #expect(stats.overall.record == WinLoss(wins: 1, losses: 1))
    }
}

@Suite struct Weeks {
    @Test func weeksRunFromMondayToSundayOldestFirst() {
        let stats = MatchStats(
            [
                // Semaine suivante : lundi 12 octobre.
                MatchRecord(
                    match: singles(straightLoss, startedAt: date(days: 7)), status: .finished),
                // Même semaine : lundi 5 au matin, dimanche 11 au soir.
                MatchRecord(
                    match: singles(straightWin, startedAt: date(hour: 8)), status: .finished),
                MatchRecord(
                    match: singles(straightLoss, startedAt: date(days: 6, hour: 22)),
                    status: .finished),
            ], calendar: utc)
        #expect(
            stats.weeks == [
                WeekRecord(weekStart: date(hour: 0), record: WinLoss(wins: 1, losses: 1)),
                WeekRecord(weekStart: date(days: 7, hour: 0), record: WinLoss(wins: 0, losses: 1)),
            ])
    }

    @Test func aWeekWithOnlyInterruptedMatchesIsNotShown() {
        let stats = MatchStats(
            [MatchRecord(match: singles([.me]), status: .interrupted)], calendar: utc)
        #expect(stats.weeks.isEmpty)
    }
}
