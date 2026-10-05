import ShuttleCore
import SwiftUI

/// Fiche d'un match : nommer après coup les joueurs dont on se souvient.
struct MatchDetailView: View {
    let model: HistoryModel
    let matchID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var draft: [Player: String] = [:]
    @State private var error: String?
    @FocusState private var focused: Player?

    private var record: MatchRecord? { model.records[matchID] }

    var body: some View {
        Form {
            if let record {
                Section {
                    Text(
                        MatchSummary(record).games.map { "\($0.me)–\($0.opponent)" }
                            .joined(separator: " · ")
                    )
                    .font(.title3.monospacedDigit())
                    if record.match.format == .doubles {
                        Text(conventionText(record.match.opponent1Convention))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("names.convention")
                    }
                }
                Section {
                    ForEach(PlayerNames.nameableRoles(in: record.match.format), id: \.self) {
                        role in
                        field(for: role, format: record.match.format)
                    }
                } header: {
                    Text("Joueurs")
                } footer: {
                    Text("Facultatif : laisse vide si tu ne t'en souviens pas.")
                }
                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("names.error")
                }
            }
        }
        .navigationTitle(
            record.map { $0.match.format == .singles ? "Simple" : "Double" } ?? "Match"
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Enregistrer", action: save)
                .accessibilityIdentifier("names.save")
        }
        .onAppear { draft = model.names[matchID] ?? [:] }
    }

    @ViewBuilder
    private func field(for role: Player, format: MatchFormat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(
                role.name(in: format),
                text: Binding(get: { draft[role] ?? "" }, set: { draft[role] = $0 })
            )
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .focused($focused, equals: role)
            .accessibilityIdentifier("names.field.\(role.identifier)")
            // Noms déjà utilisés, filtrés par ce qui est tapé.
            let suggestions = model.directory.suggestions(startingWith: draft[role] ?? "")
                .filter { $0 != draft[role] }
            if focused == role, !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(suggestions, id: \.self) { name in
                            Button(name) { draft[role] = name }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("names.suggestion.\(name)")
                        }
                    }
                }
            }
        }
    }

    private func conventionText(_ convention: Opponent1Convention) -> String {
        switch convention {
        case .receivedFirstServe: "Adv. 1 = celui qui a reçu le premier service du match."
        case .servedFirst: "Adv. 1 = celui qui a servi le premier échange du match."
        }
    }

    private func save() {
        switch model.saveNames(draft, forMatch: matchID) {
        case .valid:
            dismiss()
        case .duplicate(let name):
            error = "\(name) ne peut pas tenir deux rôles dans le même match."
        }
    }
}
