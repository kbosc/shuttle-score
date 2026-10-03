import ShuttleCore
import SwiftUI

struct SetupView: View {
    let onStart: (Side) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("Qui sert en premier ?")
                .font(.headline)
            Button("Moi") { onStart(.me) }
                .accessibilityIdentifier("setup.firstServer.me")
            Button("Adversaire") { onStart(.opponent) }
                .accessibilityIdentifier("setup.firstServer.opponent")
        }
    }
}

#Preview {
    SetupView { _ in }
}
