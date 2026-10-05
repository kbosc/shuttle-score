import ShuttleCore
import SwiftUI
import WatchKit

/// Écran de match : la moitié haute donne le point à l'adversaire, la moitié basse à moi.
struct MatchView: View {
    @Binding var match: Match
    /// Annuler avant le premier point : retour au choix du premier service.
    let onUndoFirstService: () -> Void
    let onNewMatch: () -> Void

    var body: some View {
        let state = match.state
        VStack(spacing: 0) {
            SideHalf(side: .opponent, format: match.format, rules: match.rules, state: state) {
                score(.opponent)
            }
            CenterBar(
                state: state, rules: match.rules, undo: undo, onNewMatch: onNewMatch)
            SideHalf(side: .me, format: match.format, rules: match.rules, state: state) {
                score(.me)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func undo() {
        if match.events.isEmpty {
            onUndoFirstService()
        } else {
            match.undo()
        }
    }

    private func score(_ side: Side) {
        match.recordRally(wonBy: side)
        WKInterfaceDevice.current().play(.click)
    }
}

private struct SideHalf: View {
    let side: Side
    let format: MatchFormat
    let rules: ScoringRules
    let state: MatchState
    let action: () -> Void

    private var isServing: Bool { state.servingSide == side }
    /// La moitié qui sert est allumée ; en fin de match, celle du vainqueur.
    private var isHighlighted: Bool { isServing || state.winner == side }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text("\(bigNumber)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .accessibilityIdentifier("match.score.\(side.identifier)")
                if state.isOver {
                    // En un seul set, le gros chiffre montre déjà le score final.
                    if !isSingleGame {
                        Text(setScores)
                            .font(.caption2)
                    }
                } else {
                    // Les deux cases du camp, dans l'ordre où je les vois depuis ma place.
                    HStack(spacing: 0) {
                        ForEach(Array(side.courtsSeenFromMe.enumerated()), id: \.offset) {
                            index, court in
                            CourtSlot(
                                player: state.player(of: side, in: court), state: state,
                                format: format
                            )
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier(
                                "match.court.\(side.identifier).\(index == 0 ? "screenLeft" : "screenRight")"
                            )
                        }
                    }
                }
            }
            // Moitié du bas : les noms s'écartent du bord arrondi de l'écran.
            .padding(.bottom, side == .me ? 12 : 0)
            .foregroundStyle(isHighlighted ? Color.black : Color.white.opacity(0.85))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isHighlighted ? Color.serving : Color.gray.opacity(0.15))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Pas de .disabled : il estomperait la couleur du vainqueur en fin de match.
        .allowsHitTesting(!state.isOver)
        .accessibilityIdentifier("match.half.\(side.identifier)")
    }

    /// Pendant le match : les points du set en cours. Après : les sets gagnés,
    /// ou les points du set si le match se joue en un seul set (5 points).
    private var bigNumber: Int {
        guard state.isOver else { return state.currentGame[side] }
        if isSingleGame, let last = state.completedGames.last { return last[side] }
        return state.gamesWon(by: side)
    }

    private var isSingleGame: Bool { rules.gamesToWinMatch == 1 }

    /// En fin de match : les points de ce camp, set par set.
    private var setScores: String {
        state.completedGames.map { "\($0[side])" }.joined(separator: " · ")
    }
}

/// Une case du terrain : le joueur qui s'y tient, en gras avec l'icône s'il sert,
/// souligné s'il reçoit. Vide en simple pour la case inoccupée.
private struct CourtSlot: View {
    let player: Player?
    let state: MatchState
    let format: MatchFormat

    var body: some View {
        if let player {
            let isServer = state.server == player
            let isReceiver = state.receiver == player
            HStack(spacing: 2) {
                if isServer {
                    Image(systemName: "figure.badminton")
                }
                Text(player.name(in: format))
                    .fontWeight(isServer ? .bold : .regular)
                    .underline(isReceiver)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .font(.footnote)
            .accessibilityElement(children: .combine)
            .accessibilityValue(isServer ? "sert" : isReceiver ? "reçoit" : "")
        } else {
            Color.clear.frame(height: 1)
        }
    }
}

private struct CenterBar: View {
    let state: MatchState
    let rules: ScoringRules
    let undo: () -> Void
    let onNewMatch: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: undo) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: Self.target.width, minHeight: Self.target.height)
                    .background(Color.gray.opacity(0.35), in: Capsule())
                    .contentShape(Capsule())
            }
            .accessibilityLabel("Annuler le dernier point")
            .accessibilityIdentifier("match.undo")

            if let winner = state.winner {
                Text(winner == .me ? "Gagné" : "Perdu")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("match.result")
                Button(action: onNewMatch) {
                    Text("Nouveau")
                        .font(.footnote.weight(.semibold))
                        .fixedSize()
                        .padding(.horizontal, 8)
                        .frame(minHeight: Self.target.height)
                        .background(Color.gray.opacity(0.35), in: Capsule())
                        .contentShape(Capsule())
                }
                .accessibilityIdentifier("match.new")
            } else {
                Text(progress)
                    .font(.footnote)
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("match.games")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        // Marge morte autour des boutons : un tap un peu à côté ne marque pas de point.
        .padding(.vertical, 4)
        .frame(height: Self.target.height + 8)
        .background(Color.black)
    }

    /// En un seul set (5 points), il n'y a pas de sets à compter : on rappelle le format.
    private var progress: String {
        rules.gamesToWinMatch == 1
            ? "\(rules.pointsToWinGame) points"
            : "Sets \(state.gamesWon(by: .me)) – \(state.gamesWon(by: .opponent))"
    }

    /// Cible minimale d'un bouton au doigt (recommandation Apple : 44 pt).
    private static let target = CGSize(width: 64, height: 44)
}

extension Color {
    /// Vert-jaune vif : lisible d'un coup d'œil sur le fond noir de la montre.
    fileprivate static let serving = Color(red: 0.78, green: 1.0, blue: 0.18)
}

extension Side {
    fileprivate var identifier: String {
        switch self {
        case .me: "me"
        case .opponent: "opponent"
        }
    }
}

#Preview("En cours") {
    @Previewable @State var match = Match(firstServer: .me)
    MatchView(match: $match, onUndoFirstService: {}, onNewMatch: {})
}
