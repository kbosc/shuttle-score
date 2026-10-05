import Foundation
import ShuttleCore
import WatchConnectivity

/// Reçoit les matchs envoyés par la montre (WatchConnectivity) et les passe au récepteur.
@MainActor
final class PhoneConnectivity: NSObject, WCSessionDelegate {
    private let receiver: MatchSyncReceiver
    private let onReceive: @MainActor () -> Void

    init(receiver: MatchSyncReceiver, onReceive: @escaping @MainActor () -> Void) {
        self.receiver = receiver
        self.onReceive = onReceive
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    nonisolated func session(
        _ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        guard let data = userInfo[SyncKey.message] as? Data else { return }
        Task { @MainActor in
            self.receiver.receive(data)
            self.onReceive()
        }
    }

    nonisolated func session(
        _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Changement de montre jumelée : on se réactive pour la nouvelle.
        WCSession.default.activate()
    }
}

enum SyncKey {
    static let message = "message"
}
