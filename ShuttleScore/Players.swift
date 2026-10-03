import ShuttleCore

extension Player {
    /// Nom affiché. En simple, le seul adversaire s'appelle « Adversaire ».
    func name(in format: MatchFormat) -> String {
        switch self {
        case .me: "Moi"
        case .partner: "Partenaire"
        case .opponent1: format == .singles ? "Adversaire" : "Adv. 1"
        case .opponent2: "Adv. 2"
        }
    }

    /// Suffixe des `accessibilityIdentifier`, utilisé par les tests UI.
    var identifier: String {
        switch self {
        case .me: "me"
        case .partner: "partner"
        case .opponent1: "opponent1"
        case .opponent2: "opponent2"
        }
    }

    static func players(of side: Side, in format: MatchFormat) -> [Player] {
        switch (side, format) {
        case (.me, .singles): [.me]
        case (.opponent, .singles): [.opponent1]
        case (.me, .doubles): [.me, .partner]
        case (.opponent, .doubles): [.opponent1, .opponent2]
        }
    }
}
