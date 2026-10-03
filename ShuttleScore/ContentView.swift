import ShuttleCore
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("ShuttleScore — \(ScoringRules.threeByFifteen.pointsToWinGame) pts")
    }
}

#Preview {
    ContentView()
}
