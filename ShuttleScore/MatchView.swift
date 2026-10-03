import ShuttleCore
import SwiftUI
import WatchKit

/// Écran de match : la moitié haute donne le point à l'adversaire, la moitié basse à moi.
struct MatchView: View {
    @Binding var match: Match
    let onNewMatch: () -> Void

    var body: some View {
        let state = match.state
        VStack(spacing: 0) {
            SideHalf(side: .opponent, name: "Adversaire", state: state) { score(.opponent) }
            CenterBar(
                state: state, canUndo: !match.rallies.isEmpty, undo: { match.undo() },
                onNewMatch: onNewMatch)
            SideHalf(side: .me, name: "Moi", state: state) { score(.me) }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func score(_ side: Side) {
        match.recordRally(wonBy: side)
        WKInterfaceDevice.current().play(.click)
    }
}

private struct SideHalf: View {
    let side: Side
    let name: String
    let state: MatchState
    let action: () -> Void

    private var isServing: Bool { state.server == side }
    /// La moitié qui sert est allumée ; en fin de match, celle du vainqueur.
    private var isHighlighted: Bool { isServing || state.winner == side }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text("\(bigNumber)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .accessibilityIdentifier("match.score.\(side.identifier)")
                HStack(spacing: 4) {
                    if isServing {
                        Image(systemName: "figure.badminton")
                    }
                    Text(caption)
                }
                .font(.caption2.weight(isServing ? .bold : .regular))
            }
            .foregroundStyle(isHighlighted ? Color.black : Color.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isHighlighted ? Color.serving : Color.gray.opacity(0.15))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Pas de .disabled : il estomperait la couleur du vainqueur en fin de match.
        .allowsHitTesting(!state.isOver)
        .accessibilityIdentifier("match.half.\(side.identifier)")
    }

    /// Pendant le match : les points du set en cours. Après : les sets gagnés.
    private var bigNumber: Int {
        state.isOver ? state.gamesWon(by: side) : state.currentGame[side]
    }

    private var caption: String {
        if state.isOver {
            return state.completedGames.map { "\($0[side])" }.joined(separator: " · ")
        }
        guard isServing, let court = state.serviceCourt else { return name }
        // La couleur et la position disent déjà qui sert : on garde la place pour la case.
        return "Sert \(court == .right ? "à droite" : "à gauche")"
    }
}

private struct CenterBar: View {
    let state: MatchState
    let canUndo: Bool
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
            .disabled(!canUndo)
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
                Text("Sets \(state.gamesWon(by: .me)) – \(state.gamesWon(by: .opponent))")
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
    MatchView(match: $match, onNewMatch: {})
}
