import Foundation
import ShuttleCore
import Testing

@Suite struct Names {
    @Test func namesAreTrimmedAndEmptyMeansNoName() {
        #expect(PlayerNames.normalized("  Lucas ") == "Lucas")
        #expect(PlayerNames.normalized("   ") == nil)
        #expect(PlayerNames.normalized("") == nil)
    }

    @Test func lucasAndLucasAreTheSamePerson() {
        #expect(PlayerNames.key("Lucas") == PlayerNames.key("lucas"))
        #expect(PlayerNames.key("Lucas") == PlayerNames.key(" LUCAS "))
        #expect(PlayerNames.key("Lucas") != PlayerNames.key("Luca"))
    }

    @Test func meIsNeverNamedAndRolesDependOnTheFormat() {
        #expect(PlayerNames.nameableRoles(in: .singles) == [.opponent1])
        #expect(PlayerNames.nameableRoles(in: .doubles) == [.partner, .opponent1, .opponent2])
    }
}

@Suite struct Convention {
    @Test func whenMyTeamServedFirstOpponent1ReceivedIt() {
        let match = Match(doublesFirstService: .firstDoublesService(myTeamServer: .partner))
        #expect(match.opponent1Convention == .receivedFirstServe)
    }

    @Test func whenTheOpponentsServedFirstOpponent1ServedIt() {
        let match = Match(doublesFirstService: .firstDoublesService(opponentsServeTo: .me))
        #expect(match.opponent1Convention == .servedFirst)
        #expect(Match(firstServer: .opponent).opponent1Convention == .servedFirst)
    }
}

@Suite struct Directory {
    private let directory = PlayerDirectory([
        [.opponent1: "Lucas", .opponent2: "Marc"],
        [.partner: "lucas", .opponent1: "Léa"],
        [.opponent1: "Marc"],
    ])

    @Test func suggestionsAreDistinctFilteredAndSorted() {
        #expect(directory.suggestions(startingWith: "") == ["Léa", "Lucas", "Marc"])
        #expect(directory.suggestions(startingWith: "lu") == ["Lucas"])
        #expect(directory.suggestions(startingWith: "M") == ["Marc"])
        #expect(directory.suggestions(startingWith: "z").isEmpty)
    }

    @Test func aKnownPersonKeepsItsFirstSpelling() {
        #expect(directory.canonical("  LUCAS ") == "Lucas")
        #expect(directory.canonical("Paul") == "Paul")
        #expect(directory.canonical("  ") == nil)
    }

    @Test func namingCleansAndUsesTheKnownSpelling() {
        let result = directory.naming(
            [.partner: " paul ", .opponent1: "lucas", .opponent2: ""], in: .doubles)
        #expect(result == .valid([.partner: "paul", .opponent1: "Lucas"]))
    }

    @Test func roleThatCannotBeNamedIsIgnored() {
        let result = directory.naming(
            [.me: "Kévin", .partner: "Paul", .opponent1: "Léa"], in: .singles)
        #expect(result == .valid([.opponent1: "Léa"]))
    }

    @Test func theSamePersonCannotHoldTwoRolesOfAMatch() {
        let result = directory.naming([.opponent1: "Lucas", .opponent2: "LUCAS"], in: .doubles)
        #expect(result == .duplicate(name: "Lucas"))
    }
}

@Suite struct Editing {
    @Test func theSpellingOfANameCanBeFixedInTheMatchBeingEdited() {
        let only = UUID()
        let directory = PlayerDirectory.forEditing(
            only, namesNewestFirst: [(only, [.opponent1: "lucas"])])
        #expect(
            directory.naming([.opponent1: "Lucas"], in: .singles) == .valid([.opponent1: "Lucas"]))
    }

    @Test func otherMatchesStillGiveTheReferenceSpelling() {
        let editing = UUID()
        let other = UUID()
        let directory = PlayerDirectory.forEditing(
            editing,
            namesNewestFirst: [(editing, [.opponent1: "lucas"]), (other, [.partner: "Lucas"])])
        #expect(
            directory.naming([.opponent1: "LUCAS"], in: .singles) == .valid([.opponent1: "Lucas"]))
    }
}

@Suite struct ByPlayer {
    private func finished(won: Bool, format: MatchFormat = .doubles) -> Match {
        var match =
            format == .singles
            ? Match(firstServer: .me)
            : Match(doublesFirstService: .firstDoublesService(myTeamServer: .me))
        let side: Side = won ? .me : .opponent
        for _ in 0..<15 { match.recordRally(wonBy: side) }
        if format == .doubles {
            let server: Player = won ? .me : .opponent1
            match.chooseService(
                ServiceChoice(server: server, receiver: won ? .opponent1 : .me))
        }
        for _ in 0..<15 { match.recordRally(wonBy: side) }
        return match
    }

    @Test func recordsAreSplitBetweenWithAndAgainst() {
        let win = finished(won: true)
        let loss = finished(won: false)
        let singlesWin = finished(won: true, format: .singles)
        let interrupted = Match(firstServer: .me)
        let records = [
            MatchRecord(match: win, status: .finished),
            MatchRecord(match: loss, status: .finished),
            MatchRecord(match: singlesWin, status: .finished),
            MatchRecord(match: interrupted, status: .interrupted),
        ]
        let names: [UUID: [Player: String]] = [
            win.id: [.partner: "Lucas", .opponent1: "Marc"],
            loss.id: [.opponent1: "Lucas", .opponent2: "Marc"],
            singlesWin.id: [.opponent1: "Marc"],
            interrupted.id: [.opponent1: "Léa"],
        ]
        let players = MatchStats.byPlayer(records, names: names)
        // Léa n'apparaît que dans un match interrompu sans aucun point : pas d'entrée.
        #expect(players.map(\.name) == ["Marc", "Lucas"])
        #expect(players.map(\.with) == [WinLoss(wins: 0, losses: 0), WinLoss(wins: 1, losses: 0)])
        #expect(
            players.map(\.against) == [WinLoss(wins: 2, losses: 1), WinLoss(wins: 0, losses: 1)])
    }

    @Test func pointsWithAndAgainstIncludeInterruptedMatches() {
        // Double interrompu. Échanges : je sers et gagne, je sers et perds, l'adversaire sert
        // et perd, mon camp sert et gagne → service 2/3, réception 1/1.
        var match = Match(doublesFirstService: .firstDoublesService(myTeamServer: .me))
        for side: Side in [.me, .opponent, .me, .me] { match.recordRally(wonBy: side) }
        let players = MatchStats.byPlayer(
            [MatchRecord(match: match, status: .interrupted)],
            names: [match.id: [.partner: "Paul", .opponent1: "Léa"]])
        let split = PointSplit(
            serve: PointRate(won: 2, played: 3), receive: PointRate(won: 1, played: 1))
        let none = WinLoss(wins: 0, losses: 0)
        #expect(
            players == [
                PlayerRecord(name: "Léa", with: none, against: none, againstPoints: split),
                PlayerRecord(name: "Paul", with: none, against: none, withPoints: split),
            ])
    }

    @Test func pointsAddUpAcrossMatchesWithTheSamePerson() {
        let win = finished(won: true)
        let loss = finished(won: false)
        let players = MatchStats.byPlayer(
            [
                MatchRecord(match: win, status: .finished),
                MatchRecord(match: loss, status: .finished),
            ],
            names: [win.id: [.opponent1: "Marc"], loss.id: [.opponent2: "marc"]])
        // Victoire : 30 échanges servis et gagnés par mon camp. Défaite : je sers le 1er
        // échange et le perds, puis l'adversaire sert les 29 autres et les gagne.
        #expect(players.count == 1)
        #expect(players.first?.againstPoints.serve == PointRate(won: 30, played: 31))
        #expect(players.first?.againstPoints.receive == PointRate(won: 0, played: 29))
    }
}
