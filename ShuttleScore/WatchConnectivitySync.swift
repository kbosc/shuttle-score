import Foundation
import ShuttleCore
import WatchConnectivity

/// Envoie les matchs à l'iPhone. `transferUserInfo` les met en file d'attente : ils partent
/// dès que l'iPhone est joignable, même si l'app iPhone est fermée.
@MainActor
final class WatchConnectivitySync: NSObject, MatchSync, WCSessionDelegate {
    /// Messages en attente de l'activation de la session.
    private var pending: [Data] = []
    private var isActivated = false

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ message: SyncMessage) {
        guard let data = try? message.encoded() else { return }
        if isActivated {
            WCSession.default.transferUserInfo([SyncKey.message: data])
        } else {
            pending.append(data)
        }
    }

    nonisolated func session(
        _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        guard activationState == .activated else { return }
        Task { @MainActor in
            isActivated = true
            for data in pending { WCSession.default.transferUserInfo([SyncKey.message: data]) }
            pending = []
        }
    }
}

enum SyncKey {
    static let message = "message"
}
