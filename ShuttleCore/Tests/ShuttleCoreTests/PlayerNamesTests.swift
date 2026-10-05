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
        #expect(
            MatchStats.byPlayer(records, names: names) == [
                PlayerRecord(
                    name: "Marc", with: WinLoss(wins: 0, losses: 0),
                    against: WinLoss(wins: 2, losses: 1)),
                PlayerRecord(
                    name: "Lucas", with: WinLoss(wins: 1, losses: 0),
                    against: WinLoss(wins: 0, losses: 1)),
            ])
    }
}
