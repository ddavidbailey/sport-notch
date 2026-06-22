import SwiftUI
import FootballNotchCore

private let notchAnimation = Animation.spring(response: 0.34, dampingFraction: 0.82)

/// A transient green "+N" that animates in beside the team that just scored.
struct GoalBadge: View {
    let delta: Int
    let side: GoalSide

    var body: some View {
        Text("+\(delta)")
            .font(.system(size: 14, weight: .heavy))
            .foregroundStyle(.green)
            .frame(maxWidth: .infinity,
                   alignment: side == .home ? .leading : .trailing)
            .offset(y: -16)
            .transition(.scale.combined(with: .opacity).combined(with: .move(edge: .top)))
    }
}

struct NotchRootView: View {
    @ObservedObject var store: MatchStore
    @State private var expanded = false
    @State private var metrics = NotchMetrics.fallback
    var onCardFrame: (CGRect) -> Void = { _ in }

    private var topCornerRadius: CGFloat { expanded ? 15 : 7 }
    private var bottomCornerRadius: CGFloat { expanded ? 22 : 14 }
    private var topContentInset: CGFloat { metrics.hasNotch ? metrics.height : 8 }

    private var shape: AnyShape {
        if metrics.hasNotch {
            return AnyShape(NotchShape(topCornerRadius: topCornerRadius,
                                       bottomCornerRadius: bottomCornerRadius))
        }
        return AnyShape(RoundedBottomRectangle(radius: expanded ? 20 : 14))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
            card
                .background(
                    GeometryReader { proxy in
                        let frame = proxy.frame(in: .named("overlay"))
                        Color.clear
                            .onAppear { onCardFrame(frame) }
                            .onChange(of: frame) { _, new in onCardFrame(new) }
                    }
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .coordinateSpace(name: "overlay")
        .onAppear { metrics = NotchMetrics.current }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            FollowedMatchView(match: store.followedMatch,
                              expanded: expanded,
                              goalFlash: store.followedMatch.flatMap { store.goalFlashes[$0.id] })
                .frame(maxWidth: .infinity, alignment: .center)

            if expanded {
                SelectionList(
                    matches: store.selectableMatches,
                    selectedId: store.followedMatch?.id,
                    select: { store.select(matchId: $0) }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, topContentInset + 4)
        .padding(.bottom, expanded ? 14 : 8)
        .frame(minWidth: max(metrics.width, 120))
        .fixedSize()
        .background(Color.black, in: shape)
        .overlay {
            if !metrics.hasNotch {
                shape.stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
        }
        .clipShape(shape)
        .shadow(color: .black.opacity(expanded ? 0.45 : 0.2),
                radius: expanded ? 12 : 4, y: 2)
        .foregroundStyle(.white)
        .contentShape(shape)
        .onHover { inside in
            withAnimation(notchAnimation) { expanded = inside }
        }
        .animation(notchAnimation, value: expanded)
    }
}

/// The match the user is following: score once live, otherwise a kickoff countdown.
struct FollowedMatchView: View {
    let match: Match?
    let expanded: Bool
    var goalFlash: GoalFlash? = nil

    @State private var shownGoal: GoalFlash?
    @State private var lastShownToken = 0
    @State private var clearTask: Task<Void, Never>?

    var body: some View {
        if let match {
            VStack(spacing: 5) {
                ZStack {
                    TeamsRow(match: match, showScore: match.isLive)

                    if let shownGoal {
                        GoalBadge(delta: shownGoal.delta, side: shownGoal.side)
                    }
                }
                .onChange(of: goalFlash?.token) { _, newToken in
                    guard let flash = goalFlash, let token = newToken, token > lastShownToken else { return }
                    lastShownToken = token
                    clearTask?.cancel()
                    withAnimation(notchAnimation) {
                        shownGoal = flash
                    }
                    clearTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        withAnimation(notchAnimation) {
                            shownGoal = nil
                        }
                    }
                }

                if match.isLive {
                    if !match.clock.isEmpty {
                        Text(match.clock)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                } else {
                    VStack(spacing: 2) {
                        if expanded {
                            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                                Text(countdownString(to: match.kickoff, now: ctx.date))
                                    .font(.system(size: 16, weight: .semibold))
                                    .monospacedDigit()
                            }
                        }
                        Text(kickoffString(match.kickoff, now: Date()))
                            .font(.system(size: expanded ? 12 : 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } else {
            Text("No upcoming matches")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }
}

/// The selection area: the soonest matches, tap to follow. Highlights the current pick.
struct SelectionList: View {
    let matches: [Match]
    let selectedId: String?
    let select: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Soonest matches")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 8)
                .padding(.bottom, 2)

            if matches.isEmpty {
                Text("No matches scheduled")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
            } else {
                ForEach(matches) { m in
                    Button { select(m.id) } label: {
                        SelectionRow(match: m, isSelected: m.id == selectedId)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SelectionRow: View {
    let match: Match
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            TeamsRow(match: match, showScore: match.isLive)

            Spacer(minLength: 12)

            if match.isLive {
                Text("LIVE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.green)
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text(countdownString(to: match.kickoff, now: ctx.date))
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.16) : .clear)
        }
        .contentShape(Rectangle())
    }
}

/// Flags + abbreviations, optionally with the score between teams.
struct TeamsRow: View {
    let match: Match
    let showScore: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(match.home.flag)
            Text(match.home.abbreviation).fontWeight(.semibold)

            if showScore {
                Text("\(match.homeScore)").bold()
                Text("–").foregroundStyle(.secondary)
                Text("\(match.awayScore)").bold()
            } else {
                Text("vs").font(.system(size: 11)).foregroundStyle(.secondary)
            }

            Text(match.away.abbreviation).fontWeight(.semibold)
            Text(match.away.flag)
        }
        .font(.system(size: 13))
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }
}
