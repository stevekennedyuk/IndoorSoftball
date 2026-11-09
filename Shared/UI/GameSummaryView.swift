import SwiftUI

/// End-of-game (or history) report: final score, winner, line score, and for
/// every inning the plus / minus tally of each half plus the score at the end
/// of the inning. Each half's individual entries can be expanded.
struct GameSummaryView: View {
    let game: Game
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 18) {
            resultBanner
            finalScores
            if !compact {
                card { LineScoreView(game: game) }
            }
            ForEach(1...max(1, game.inningsCount), id: \.self) { inning in
                InningCard(game: game, inning: inning, compact: compact)
            }
            footer
        }
    }

    // MARK: Pieces

    private var resultBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: game.leader == nil ? "equal.circle.fill" : "trophy.fill")
                .foregroundStyle(game.leader.map(Theme.color) ?? .secondary)
            Text(game.isFinished ? game.resultText : "In progress – \(game.current.label)")
                .font(compact ? .headline : .title2.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
    }

    private var finalScores: some View {
        HStack(spacing: compact ? 6 : 12) {
            ForEach(Team.allCases, id: \.self) { team in
                VStack(spacing: 2) {
                    Text(game.name(team))
                        .font(compact ? .caption2 : .subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(game.total(team).scoreString)
                        .font(.system(size: compact ? 30 : 52, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                    if !compact {
                        Text("+\(game.positiveTotal(team))  \(game.negativeTotal(team) == 0 ? "−0" : game.negativeTotal(team).signedString)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, compact ? 6 : 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.color(team).opacity(game.winner == team ? 0.35 : 0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.color(team), lineWidth: game.winner == team ? 2 : 0)
                )
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let loc = game.location { Text("Location: \(loc)") }
            Text("Play started \(game.playStart.formatted(date: .abbreviated, time: .shortened))")
            if let end = game.endedAt {
                Text("Finished \(end.formatted(date: .omitted, time: .shortened))")
            }
            Text(rulesSummary)
            if !game.scoredOn.isEmpty { Text("Scored on \(game.scoredOn)") }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private var rulesSummary: String {
        let s = game.settings
        return "\(s.innings) innings × \(Theme.duration(s.halfInningSeconds)) · HR \(s.homeRunPoints.signedString)"
    }

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .padding(compact ? 8 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
    }
}

/// One inning: each half's + / − / net and the score at the end of the inning.
struct InningCard: View {
    let game: Game
    let inning: Int
    var compact = false
    @State private var expanded: Set<Int> = []

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            Text("Inning \(inning)")
                .font(compact ? .caption.weight(.bold) : .headline)
                .foregroundStyle(.secondary)
            ForEach(Team.allCases, id: \.self) { team in
                if let h = game.half(team: team, inning: inning) {
                    halfRow(h, team: team)
                }
            }
            if let end = endOfInning {
                Divider()
                HStack {
                    Text("End of inning \(inning)")
                        .font(compact ? .caption2 : .subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(end)
                        .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.bold))
                        .monospacedDigit()
                }
            }
        }
        .padding(compact ? 8 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
    }

    private var endOfInning: String? {
        guard let bottom = game.half(team: .home, inning: inning), game.isReached(bottom) else { return nil }
        let a = game.cumulative(.away, throughInning: inning)
        let h = game.cumulative(.home, throughInning: inning)
        if compact { return "\(a.scoreString) – \(h.scoreString)" }
        return "\(game.awayName) \(a.scoreString) – \(game.homeName) \(h.scoreString)"
    }

    @ViewBuilder
    private func halfRow(_ h: HalfInning, team: Team) -> some View {
        let reached = game.isReached(h)
        VStack(alignment: .leading, spacing: 4) {
            Button {
                guard reached, !h.events.isEmpty else { return }
                if expanded.contains(h.index) { expanded.remove(h.index) } else { expanded.insert(h.index) }
            } label: {
                HStack(spacing: compact ? 4 : 10) {
                    Circle().fill(Theme.color(team)).frame(width: 7, height: 7)
                    Text(compact ? (h.isTop ? "Top" : "Bot") : "\(h.isTop ? "Top" : "Bottom") – \(game.name(team))")
                        .font(compact ? .caption2 : .subheadline)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if reached {
                        Text("+\(h.positive)").foregroundStyle(Theme.positive)
                        Text(h.negative == 0 ? "−0" : h.negative.signedString).foregroundStyle(Theme.negative)
                        Text("= \(h.net.scoreString)")
                            .fontWeight(.bold)
                            .frame(minWidth: compact ? 30 : 44, alignment: .trailing)
                        if !compact && !h.events.isEmpty {
                            Image(systemName: expanded.contains(h.index) ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("not played").foregroundStyle(.tertiary)
                    }
                }
                .font(compact ? .caption2.monospacedDigit() : .subheadline.monospacedDigit())
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded.contains(h.index) {
                ForEach(h.events) { e in
                    HStack {
                        Image(systemName: e.kind.symbol).foregroundStyle(Theme.pointsColor(e.points))
                        Text(e.description)
                        Spacer()
                        Text(e.points.signedString).foregroundStyle(Theme.pointsColor(e.points))
                    }
                    .font(.caption.monospacedDigit())
                    .padding(.leading, 18)
                }
            }
        }
    }
}
