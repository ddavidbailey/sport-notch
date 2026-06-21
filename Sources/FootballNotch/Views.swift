import SwiftUI
import FootballNotchCore

enum NotchScreen { case collapsed, expanded, menu }

private struct ContentSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct NotchRootView: View {
    @ObservedObject var store: MatchStore
    @State private var screen: NotchScreen = .collapsed
    var onResize: (CGSize) -> Void = { _ in }

    var body: some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
            .onHover { inside in
                guard screen != .menu else { return }
                screen = inside ? .expanded : .collapsed
            }
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ContentSizeKey.self, value: proxy.size)
                }
            )
            .onPreferenceChange(ContentSizeKey.self) { size in
                MainActor.assumeIsolated { onResize(size) }
            }
    }

    @ViewBuilder private var content: some View {
        switch screen {
        case .collapsed:
            ScoreStrip(match: store.followedMatch, next: store.nextMatch)
        case .expanded:
            ExpandedView(match: store.followedMatch,
                         next: store.nextMatch,
                         openMenu: { screen = .menu })
        case .menu:
            MenuView(matches: store.liveMatches,
                     select: { store.select(matchId: $0); screen = .expanded },
                     back: { screen = .expanded })
        }
    }
}

struct ScoreStrip: View {
    let match: Match?
    let next: Match?

    var body: some View {
        if let m = match {
            HStack(spacing: 6) {
                Text(m.home.flag); Text(m.home.abbreviation).bold()
                Text("\(m.homeScore)").bold()
                Text("–")
                Text("\(m.awayScore)").bold()
                Text(m.away.abbreviation).bold(); Text(m.away.flag)
            }
            .font(.system(size: 13))
        } else if let n = next {
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                HStack(spacing: 6) {
                    Text(n.home.flag); Text(n.home.abbreviation)
                    Text(countdownString(to: n.kickoff, now: ctx.date))
                        .monospacedDigit()
                    Text(n.away.abbreviation); Text(n.away.flag)
                }
                .font(.system(size: 13))
            }
        } else {
            Text("No live matches")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

struct ExpandedView: View {
    let match: Match?
    let next: Match?
    let openMenu: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            ScoreStrip(match: match, next: next)
            HStack {
                if let m = match {
                    Text(m.clock).font(.system(size: 12, weight: .semibold))
                }
                Spacer()
                Button(action: openMenu) {
                    Image(systemName: "list.bullet")
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct MenuView: View {
    let matches: [Match]
    let select: (String) -> Void
    let back: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Button(action: back) { Image(systemName: "chevron.left") }
                    .buttonStyle(.plain)
                Text("Live matches").font(.caption).bold()
            }
            if matches.isEmpty {
                Text("No live matches").font(.caption)
            } else {
                ForEach(matches) { m in
                    Button { select(m.id) } label: {
                        HStack(spacing: 4) {
                            Text(m.home.flag); Text(m.home.abbreviation)
                            Text("\(m.homeScore)–\(m.awayScore)").bold()
                            Text(m.away.abbreviation); Text(m.away.flag)
                        }
                        .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
