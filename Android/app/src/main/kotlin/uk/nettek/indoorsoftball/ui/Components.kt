package uk.nettek.indoorsoftball.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import uk.nettek.indoorsoftball.AppState
import uk.nettek.indoorsoftball.shared.ClockStatus
import uk.nettek.indoorsoftball.shared.EventKind
import uk.nettek.indoorsoftball.shared.Game
import uk.nettek.indoorsoftball.shared.ScoringType
import uk.nettek.indoorsoftball.shared.Team
import uk.nettek.indoorsoftball.shared.clockText
import uk.nettek.indoorsoftball.shared.durationText
import uk.nettek.indoorsoftball.shared.score
import uk.nettek.indoorsoftball.shared.signed

/** Colours shared with the iOS app (Shared/UI/Theme.swift). */
object Palette {
    val Away = Color(0xFF4294FF)
    val Home = Color(0xFFFF8033)
    val Positive = Color(0xFF38D16B)
    val Negative = Color(0xFFFF5252)
    val Warning = Color(0xFFFFC20D)
    val Idle = Color(0xFF8C8C8C)
    val Paused = Color(0xFF8CB3FF)
    val Card = Color(0xFF212121)
    val CardRaised = Color(0xFF303030)
    val Powder = Color(0xFFB2D3EE)
    val Secondary = Color(0xFF9898A0)

    fun team(team: Team) = if (team == Team.AWAY) Away else Home
    fun points(p: Int) = if (p > 0) Positive else if (p < 0) Negative else Idle
    fun clock(status: ClockStatus) = when (status) {
        ClockStatus.READY, ClockStatus.CLOSED -> Idle
        ClockStatus.RUNNING -> Positive
        ClockStatus.PAUSED -> Paused
        ClockStatus.WARNING -> Warning
        ClockStatus.TIME_UP -> Negative
    }
}

private val Scheme = darkColorScheme(
    primary = Palette.Positive,
    onPrimary = Color.Black,
    secondary = Palette.Away,
    background = Color.Black,
    surface = Color.Black,
    surfaceVariant = Palette.Card,
    surfaceContainer = Color(0xFF121214),
    surfaceContainerHigh = Palette.Card,
    surfaceContainerHighest = Palette.CardRaised,
    error = Palette.Negative,
)

@Composable
fun AppTheme(content: @Composable () -> Unit) = MaterialTheme(colorScheme = Scheme, content = content)

val LocalApp = staticCompositionLocalOf<AppState> { error("No AppState") }

/** Sizing for the three layouts (iOS PanelSize). */
enum class PanelSize { COMPACT, REGULAR, LARGE }

private val Digits = TextStyle(fontWeight = FontWeight.Black, fontFeatureSettings = "tnum")

@Composable
fun Card(modifier: Modifier = Modifier, color: Color = Palette.Card, content: @Composable ColumnScope.() -> Unit) =
    Column(modifier.clip(RoundedCornerShape(14.dp)).background(color).padding(14.dp), content = content)

@Composable
fun Label(text: String, color: Color = Palette.Secondary) =
    Text(text, color = color, fontSize = 11.sp, fontWeight = FontWeight.Bold, maxLines = 1)

// ---------------------------------------------------------------- scoreboard

@Composable
fun ScoreHeader(g: Game, size: PanelSize) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
        TeamTile(g, Team.AWAY, size, Modifier.weight(1f))
        if (size == PanelSize.COMPACT) {
            Text("${g.current.shortLabel}/${g.inningsCount}", fontSize = 14.sp, fontWeight = FontWeight.Black, maxLines = 1)
        } else {
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.width(if (size == PanelSize.LARGE) 70.dp else 44.dp)) {
                Text(if (g.current.isTop) "TOP" else "BOT", fontSize = 11.sp, fontWeight = FontWeight.Black)
                Text("${g.current.inning}", style = Digits, fontSize = if (size == PanelSize.LARGE) 40.sp else 26.sp)
                Text("of ${g.inningsCount}", fontSize = 11.sp, color = Palette.Secondary)
            }
        }
        TeamTile(g, Team.HOME, size, Modifier.weight(1f))
    }
}

@Composable
private fun TeamTile(g: Game, team: Team, size: PanelSize, modifier: Modifier) {
    val batting = g.current.battingTeam == team
    val color = Palette.team(team)
    val shape = RoundedCornerShape(14.dp)
    val tile = modifier
        .clip(shape)
        .background(color.copy(alpha = if (batting) 0.28f else 0.10f))
        .border(if (batting) 2.dp else 1.dp, color.copy(alpha = if (batting) 1f else 0.3f), shape)
    if (size == PanelSize.COMPACT) {
        // Short screens: name and score on one line; the border shows who is batting.
        Row(tile.padding(horizontal = 10.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(g.name(team), Modifier.weight(1f), fontWeight = FontWeight.SemiBold, fontSize = 14.sp,
                maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(g.total(team).score(), style = Digits, fontSize = 26.sp, maxLines = 1)
        }
        return
    }
    Column(
        tile.padding(vertical = if (size == PanelSize.LARGE) 10.dp else 6.dp, horizontal = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(g.name(team), fontWeight = FontWeight.SemiBold, fontSize = if (size == PanelSize.LARGE) 18.sp else 15.sp,
            maxLines = 1, overflow = TextOverflow.Ellipsis)
        Text(
            g.total(team).score(), style = Digits, maxLines = 1,
            fontSize = when (size) { PanelSize.LARGE -> 68.sp; PanelSize.REGULAR -> 42.sp; PanelSize.COMPACT -> 32.sp },
        )
        Text(
            if (batting) "AT BAT" else "FIELDING", fontSize = 10.sp, fontWeight = FontWeight.Black,
            color = if (batting) Color.Black else Palette.Secondary,
            modifier = Modifier.clip(CircleShape).background(if (batting) color else Color.Transparent).padding(horizontal = 6.dp),
        )
    }
}

// ---------------------------------------------------------------- clock

/**
 * The half-inning clock. Once time is up its main button becomes
 * "Start Bottom 1" (or "End Game"); scores can still be entered until then.
 */
@Composable
fun ClockCard(g: Game, size: PanelSize, modifier: Modifier = Modifier, expand: Boolean = false) {
    val app = LocalApp.current
    val engine = app.engine
    val now = app.now
    val status = engine.clockStatus(now)
    val color = Palette.clock(status)
    val timer = g.current.timer
    val timeUp = status == ClockStatus.TIME_UP
    val shape = RoundedCornerShape(18.dp)
    val compact = size == PanelSize.COMPACT
    BoxWithConstraints(modifier) {
    // When the card fills a tablet column, the digits are sized to the height left over.
    val expandedDigits = if (expand) ((maxHeight.value - 170f) * 0.62f).coerceIn(56f, 150f).sp else 100.sp
    Column(
        Modifier
            .fillMaxWidth()
            .then(if (expand) Modifier.fillMaxHeight() else Modifier)
            .clip(shape)
            .background(if (timeUp) Palette.Negative.copy(alpha = 0.22f) else Palette.Card)
            .border(2.dp, color.copy(alpha = if (status == ClockStatus.READY || status == ClockStatus.PAUSED) 0.3f else 0.9f), shape)
            .padding(horizontal = if (size == PanelSize.LARGE) 16.dp else 10.dp, vertical = if (size == PanelSize.LARGE) 16.dp else if (compact) 6.dp else 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(if (size == PanelSize.LARGE) 10.dp else if (compact) 2.dp else 6.dp),
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            val statusText = when (status) {
                ClockStatus.READY -> "READY"
                ClockStatus.RUNNING -> "RUNNING"
                ClockStatus.PAUSED -> "PAUSED"
                ClockStatus.WARNING -> "NEARLY TIME"
                ClockStatus.TIME_UP -> "TIME – ${g.current.label} over"
                ClockStatus.CLOSED -> "FINAL"
            }
            Text(statusText, color = color, fontSize = 12.sp, fontWeight = FontWeight.Black, maxLines = 1)
            Text("${g.current.label} · ${durationText(g.settings.halfInningSeconds)}", color = Palette.Secondary, fontSize = 12.sp, maxLines = 1)
        }
        if (expand) Spacer(Modifier.weight(1f))
        // Flash the clock when time is up.
        val flash = timeUp && (now / 550) % 2 == 0L
        Text(
            clockText(engine.remaining(now)), style = Digits, color = color, maxLines = 1,
            fontSize = when {
                size == PanelSize.LARGE && expand -> expandedDigits
                size == PanelSize.LARGE -> 100.sp
                size == PanelSize.REGULAR -> 60.sp
                else -> 40.sp
            },
            modifier = Modifier.alpha(if (flash) 0.35f else 1f),
        )
        if (expand) Spacer(Modifier.weight(1f))
        LinearProgressIndicator(
            progress = { timer.progress(now) }, color = color, trackColor = Color.White.copy(alpha = 0.1f),
            modifier = Modifier.fillMaxWidth().height(8.dp).clip(CircleShape),
        )
        if (timeUp) {
            Button(
                onClick = { if (g.isLastHalf) engine.finishGame() else engine.startNextHalfAndClock() },
                colors = ButtonDefaults.buttonColors(containerColor = Palette.Negative, contentColor = Color.White),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(if (g.isLastHalf) "End Game" else "▶  Start ${g.halves[g.currentIndex + 1].label}", fontWeight = FontWeight.Bold, fontSize = 17.sp)
            }
        } else {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                FilledTonalButton(onClick = { engine.addTime(-30) }) { Text("−30s") }
                Button(
                    onClick = { engine.toggleClock() },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (timer.isRunning) Palette.Warning else Palette.Positive, contentColor = Color.Black,
                    ),
                    modifier = Modifier.weight(1f),
                ) {
                    Text(
                        if (timer.isRunning) "Pause" else if (timer.hasStarted) "▶  Resume" else "▶  Start clock",
                        fontWeight = FontWeight.Bold, fontSize = 17.sp, maxLines = 1,
                    )
                }
                FilledTonalButton(onClick = { engine.addTime(30) }) { Text("+30s") }
            }
        }
    }
    }
}

// ---------------------------------------------------------------- tallies

/** Indoor: Plus, Minus and Total for the half being scored. Outdoor: its runs. */
@Composable
fun TallyBar(g: Game, size: PanelSize) {
    val h = g.current
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        if (size != PanelSize.COMPACT) {
            Text("${h.label} – ${g.name(h.battingTeam)} batting", color = Palette.team(h.battingTeam),
                fontSize = 12.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            if (g.settings.scoring == ScoringType.OUTDOOR) {
                Stat("RUNS THIS HALF", h.net.score(), Palette.points(h.net), size, emphasised = true, Modifier.weight(1f))
            } else {
                Stat("PLUS", "+${h.positive}", Palette.Positive, size, false, Modifier.weight(1f))
                Stat("MINUS", if (h.negative == 0) "−0" else h.negative.signed(), Palette.Negative, size, false, Modifier.weight(1f))
                Stat("TOTAL", h.net.score(), Palette.points(h.net), size, emphasised = true, Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun Stat(title: String, value: String, color: Color, size: PanelSize, emphasised: Boolean, modifier: Modifier) {
    val shape = RoundedCornerShape(14.dp)
    Column(
        modifier
            .clip(shape)
            .background(if (emphasised) Palette.CardRaised else Palette.Card)
            .border(if (emphasised) 2.dp else 1.dp, color.copy(alpha = if (emphasised) 0.6f else 0.25f), shape)
            .padding(vertical = if (size == PanelSize.LARGE) 10.dp else if (size == PanelSize.COMPACT) 2.dp else 5.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Label(title)
        Text(value, style = Digits, color = color, maxLines = 1,
            fontSize = when (size) { PanelSize.LARGE -> 44.sp; PanelSize.REGULAR -> 30.sp; PanelSize.COMPACT -> 26.sp })
    }
}

// ---------------------------------------------------------------- scoring buttons

/**
 * Indoor: +1 and −1 (large), then HR, OC (out by the catcher at home) and Undo.
 * Outdoor: +1 (large) with Undo, then HR+1, HR+2 and HR+3 (2, 3 and 4 runs).
 * The top row takes all the spare height.
 */
@Composable
fun ScoringPad(g: Game, size: PanelSize, modifier: Modifier = Modifier) {
    val engine = LocalApp.current.engine
    val gap = if (size == PanelSize.COMPACT) 8.dp else 10.dp
    val lowerRow = when (size) { PanelSize.LARGE -> 110.dp; PanelSize.REGULAR -> 80.dp; PanelSize.COMPACT -> 48.dp }
    val undoWidth = when (size) { PanelSize.LARGE -> 110.dp; PanelSize.REGULAR -> 68.dp; PanelSize.COMPACT -> 60.dp }
    val big = when (size) { PanelSize.LARGE -> 60.sp; PanelSize.REGULAR -> 46.sp; PanelSize.COMPACT -> 36.sp }
    val small = when (size) { PanelSize.LARGE -> 36.sp; PanelSize.REGULAR -> 26.sp; PanelSize.COMPACT -> 20.sp }
    val showSubtitle = size != PanelSize.COMPACT
    val s = g.settings

    Column(modifier, verticalArrangement = Arrangement.spacedBy(gap)) {
        if (s.scoring == ScoringType.OUTDOOR) {
            Row(Modifier.weight(1f).heightIn(min = 60.dp), horizontalArrangement = Arrangement.spacedBy(gap)) {
                PadButton("+1", "Run", Palette.Positive, big, Modifier.weight(1f).fillMaxHeight()) { engine.record(EventKind.PLUS) }
                UndoButton(engine.canUndo, showSubtitle, Modifier.width(undoWidth).fillMaxHeight()) { engine.undo() }
            }
            Row(Modifier.height(lowerRow), horizontalArrangement = Arrangement.spacedBy(gap)) {
                for (runners in 1..3) {
                    PadButton(
                        "HR+$runners", if (showSubtitle) "${runners + 1} runs" else null, Palette.Warning, small,
                        Modifier.weight(1f).fillMaxHeight(), description = "Home run plus $runners, ${runners + 1} runs",
                    ) { engine.record(EventKind.HOME_RUN, runnersOn = runners) }
                }
            }
        } else {
            Row(Modifier.weight(1f).heightIn(min = 60.dp), horizontalArrangement = Arrangement.spacedBy(gap)) {
                PadButton("+1", "Point", Palette.Positive, big, Modifier.weight(1f).fillMaxHeight()) { engine.record(EventKind.PLUS) }
                PadButton("−1", "Minus", Palette.Negative, big, Modifier.weight(1f).fillMaxHeight()) { engine.record(EventKind.MINUS) }
            }
            Row(Modifier.height(lowerRow), horizontalArrangement = Arrangement.spacedBy(gap)) {
                PadButton(
                    "HR ${s.homeRunPoints.signed()}", if (showSubtitle) "Home Run" else null, Palette.Warning, small,
                    Modifier.weight(1f).fillMaxHeight(), description = "Home run",
                ) { engine.record(EventKind.HOME_RUN) }
                PadButton(
                    "OC ${s.outAtHomeByCatcherPoints.signed()}", if (showSubtitle) "Out by Catcher" else null, Palette.Negative, small,
                    Modifier.weight(1f).fillMaxHeight(), description = "Out by catcher at home",
                ) { engine.record(EventKind.OUT_BY_CATCHER) }
                UndoButton(engine.canUndo, showSubtitle, Modifier.width(undoWidth).fillMaxHeight()) { engine.undo() }
            }
        }
    }
}

@Composable
private fun PadButton(
    title: String, subtitle: String?, color: Color, fontSize: androidx.compose.ui.unit.TextUnit,
    modifier: Modifier, description: String? = null, enabled: Boolean = true, onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(14.dp)
    Box(
        modifier
            .clip(shape)
            .background(color.copy(alpha = 0.16f))
            .border(BorderStroke(1.5.dp, color.copy(alpha = 0.55f)), shape)
            .alpha(if (enabled) 1f else 0.4f)
            .clickable(enabled = enabled, onClick = onClick)
            .semantics { contentDescription = description ?: listOfNotNull(subtitle, title).joinToString(", ") },
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(title, style = Digits, color = color, fontSize = fontSize, maxLines = 1, softWrap = false)
            if (subtitle != null) {
                Text(subtitle, color = color, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, softWrap = false)
            }
        }
    }
}

@Composable
private fun UndoButton(enabled: Boolean, showLabel: Boolean, modifier: Modifier, onClick: () -> Unit) =
    PadButton("↩", if (showLabel) "Undo" else null, Color(0xFFBBBBBB), 26.sp, modifier, "Undo last", enabled, onClick)

// ---------------------------------------------------------------- summary

/** Classic line score: each inning's net with its plus / minus underneath, and the totals. */
@Composable
fun LineScore(g: Game, modifier: Modifier = Modifier) {
    val cell = 52.dp
    Card(modifier) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Spacer(Modifier.weight(1f))
            for (i in 1..g.inningsCount) Text("$i", Modifier.width(cell), color = Palette.Secondary, fontSize = 12.sp, textAlign = TextAlign.Center)
            Text("Total", Modifier.width(cell), color = Palette.Secondary, fontSize = 12.sp, textAlign = TextAlign.Center)
        }
        for (team in Team.entries) {
            Row(Modifier.padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                Dot(Palette.team(team))
                Text(g.name(team), Modifier.weight(1f).padding(start = 6.dp), fontWeight = FontWeight.SemiBold,
                    maxLines = 1, overflow = TextOverflow.Ellipsis)
                for (i in 1..g.inningsCount) {
                    val h = g.half(team, i)
                    Column(Modifier.width(cell), horizontalAlignment = Alignment.CenterHorizontally) {
                        if (h != null && g.isReached(h)) {
                            Text(h.net.score(), style = Digits, color = Palette.points(h.net), fontSize = 17.sp)
                            Text("+${h.positive} ${if (h.negative == 0) "−0" else h.negative.signed()}", color = Palette.Secondary, fontSize = 10.sp, maxLines = 1)
                        } else {
                            Text("–", color = Palette.Secondary)
                        }
                    }
                }
                Text(g.total(team).score(), Modifier.width(cell), style = Digits, fontSize = 20.sp, textAlign = TextAlign.Center,
                    color = if (g.winner == team) Palette.team(team) else Color.White)
            }
        }
    }
}

@Composable
fun Dot(color: Color, size: Dp = 8.dp) = Box(Modifier.size(size).clip(CircleShape).background(color))

/**
 * End-of-game (or history) report: result, final scores, line score, each
 * half's plus / minus / total and the score at the end of each inning.
 */
@Composable
fun GameSummary(g: Game) {
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text(if (g.finished) g.resultText else "In progress – ${g.current.label}", fontSize = 24.sp, fontWeight = FontWeight.Bold)
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            for (team in Team.entries) {
                val color = Palette.team(team)
                val win = g.winner == team
                val shape = RoundedCornerShape(14.dp)
                Column(
                    Modifier.weight(1f).clip(shape).background(color.copy(alpha = if (win) 0.35f else 0.15f))
                        .border(if (win) 2.dp else 0.dp, if (win) color else Color.Transparent, shape).padding(vertical = 10.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(g.name(team), fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(g.total(team).score(), style = Digits, fontSize = 48.sp)
                    Text("+${g.positiveTotal(team)}  ${if (g.negativeTotal(team) == 0) "−0" else g.negativeTotal(team).signed()}",
                        color = Palette.Secondary, fontSize = 13.sp)
                }
            }
        }
        LineScore(g, Modifier.fillMaxWidth())
        for (inning in 1..g.inningsCount) {
            Card(Modifier.fillMaxWidth()) {
                Text("Inning $inning", color = Palette.Secondary, fontWeight = FontWeight.Bold)
                for (team in Team.entries) {
                    val h = g.half(team, inning) ?: continue
                    Row(Modifier.padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                        Dot(Palette.team(team))
                        Text("${if (h.isTop) "Top" else "Bottom"} – ${g.name(team)}", Modifier.weight(1f).padding(start = 6.dp),
                            maxLines = 1, overflow = TextOverflow.Ellipsis)
                        if (g.isReached(h)) {
                            Text("+${h.positive}", color = Palette.Positive)
                            Text(if (h.negative == 0) "−0" else h.negative.signed(), Modifier.padding(start = 10.dp), color = Palette.Negative)
                            Text("= ${h.net.score()}", Modifier.width(56.dp), fontWeight = FontWeight.Bold, textAlign = TextAlign.End)
                        } else {
                            Text("not played", color = Palette.Secondary)
                        }
                    }
                }
                val bottom = g.half(Team.HOME, inning)
                if (bottom != null && g.isReached(bottom)) {
                    Row(Modifier.padding(top = 8.dp)) {
                        Text("End of inning $inning", Modifier.weight(1f), color = Palette.Secondary, fontSize = 14.sp)
                        Text("${g.awayName} ${g.cumulative(Team.AWAY, inning).score()} – ${g.homeName} ${g.cumulative(Team.HOME, inning).score()}",
                            fontWeight = FontWeight.Bold, fontSize = 14.sp, maxLines = 1)
                    }
                }
            }
        }
        Column {
            val s = g.settings
            val rules = "${s.scoring.title} scoring · ${s.innings} innings × ${durationText(s.halfInningSeconds)}" +
                if (s.scoring == ScoringType.INDOOR) " · HR ${s.homeRunPoints.signed()} · OC ${s.outAtHomeByCatcherPoints.signed()}" else ""
            for (line in listOfNotNull(
                g.location?.let { "Location: $it" },
                "Play started ${formatDateTime(g.playStart)}",
                g.endedAt?.let { "Finished ${formatTime(it)}" },
                rules,
                g.scoredOn.takeIf { it.isNotEmpty() }?.let { "Scored on $it" },
            )) Text(line, color = Palette.Secondary, fontSize = 12.sp)
        }
    }
}

fun formatDateTime(ms: Long): String = java.time.format.DateTimeFormatter.ofPattern("d MMM yyyy, HH:mm")
    .withZone(java.time.ZoneId.systemDefault()).format(java.time.Instant.ofEpochMilli(ms))

fun formatTime(ms: Long): String = java.time.format.DateTimeFormatter.ofPattern("HH:mm")
    .withZone(java.time.ZoneId.systemDefault()).format(java.time.Instant.ofEpochMilli(ms))
