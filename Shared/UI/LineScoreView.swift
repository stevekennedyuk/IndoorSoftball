import SwiftUI

/// Classic line score: one column per inning, each cell showing the half's net
/// score with its plus / minus tally underneath, and a total column.
struct LineScoreView: View {
    let game: Game
    var showTallies = true
    var compact = false

    private var innings: [Int] { Array(1...max(1, game.inningsCount)) }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .center, horizontalSpacing: compact ? 6 : 12, verticalSpacing: compact ? 3 : 8) {
                GridRow {
                    Text(" ").gridColumnAlignment(.leading)
                    ForEach(innings, id: \.self) { i in
                        Text("\(i)")
                            .font(compact ? .caption2 : .caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("Total")
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                }
                Divider().gridCellUnsizedAxes(.horizontal)
                ForEach(Team.allCases, id: \.self) { team in
                    GridRow {
                        HStack(spacing: 5) {
                            Circle().fill(Theme.color(team)).frame(width: 7, height: 7)
                            Text(game.name(team))
                                .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                                .lineLimit(1)
                                .frame(maxWidth: compact ? 56 : 130, alignment: .leading)
                        }
                        ForEach(innings, id: \.self) { i in cell(team: team, inning: i) }
                        Text(game.total(team).scoreString)
                            .font(compact ? .body.weight(.bold) : .title3.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(game.winner == team ? Theme.color(team) : .primary)
                            .frame(minWidth: compact ? 26 : 40)
                    }
                }
            }
            .padding(.vertical, compact ? 2 : 4)
        }
    }

    @ViewBuilder
    private func cell(team: Team, inning: Int) -> some View {
        if let h = game.half(team: team, inning: inning), game.isReached(h) {
            let isCurrent = !game.isFinished && h.index == game.currentIndex
            VStack(spacing: 0) {
                Text(h.net.scoreString)
                    .font(compact ? .footnote.weight(.semibold) : .body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.pointsColor(h.net))
                if showTallies && !compact {
                    Text("+\(h.positive) \(h.negative == 0 ? "−0" : h.negative.signedString)")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: compact ? 24 : 44, minHeight: compact ? 20 : 36)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isCurrent ? Theme.color(team).opacity(0.25) : Color.clear)
            )
        } else {
            Text("–")
                .foregroundStyle(.tertiary)
                .frame(minWidth: compact ? 24 : 44, minHeight: compact ? 20 : 36)
        }
    }
}
