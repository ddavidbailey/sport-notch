import SwiftUI
import FootballNotchCore

struct NotchRootView: View {
    @ObservedObject var store: MatchStore
    var body: some View {
        Text("⚽︎")
            .foregroundStyle(.white)
            .padding(8)
            .background(Color.black.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
