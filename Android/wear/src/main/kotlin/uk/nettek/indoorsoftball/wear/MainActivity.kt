package uk.nettek.indoorsoftball.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.VerticalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.ScalingLazyListScope
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.SwipeToDismissBox
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.ToggleChip
import androidx.wear.compose.material.ToggleChipDefaults
import uk.nettek.indoorsoftball.shared.ClockStatus
import uk.nettek.indoorsoftball.shared.EventKind
import uk.nettek.indoorsoftball.shared.Game
import uk.nettek.indoorsoftball.shared.GameSettings
import uk.nettek.indoorsoftball.shared.ScoringType
import uk.nettek.indoorsoftball.shared.Team
import uk.nettek.indoorsoftball.shared.clockText
import uk.nettek.indoorsoftball.shared.durationText
import uk.nettek.indoorsoftball.shared.score
import uk.nettek.indoorsoftball.shared.signed

private val Away = Color(0xFF4294FF)
private val Home = Color(0xFFFF8033)
private val Positive = Color(0xFF38D16B)
private val Negative = Color(0xFFFF5252)
private val Warning = Color(0xFFFFC20D)
private val Idle = Color(0xFF8C8C8C)
private val Paused = Color(0xFF8CB3FF)
private val Secondary = Color(0xFF9898A0)

private fun teamColor(team: Team) = if (team == Team.AWAY) Away else Home
private fun pointsColor(p: Int) = if (p > 0) Positive else if (p < 0) Negative else Idle
private fun clockColor(status: ClockStatus) = when (status) {
    ClockStatus.READY, ClockStatus.CLOSED -> Idle
    ClockStatus.RUNNING -> Positive
    ClockStatus.PAUSED -> Paused
    ClockStatus.WARNING -> Warning
    ClockStatus.TIME_UP -> Negative
}

private val LocalWear = staticCompositionLocalOf<WearState> { error("No WearState") }

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val state = (application as WearApp).state
        setContent {
            // Keep the screen on while the clock is running, so the time-up
            // alert always reaches the wrist and the countdown stays visible.
            val view = LocalView.current
            val running = state.game?.let { !it.finished && it.current.timer.isRunning } ?: false
            DisposableEffect(running) {
                view.keepScreenOn = running
                onDispose { view.keepScreenOn = false }
            }
            CompositionLocalProvider(LocalWear provides state) {
                MaterialTheme { WearRoot() }
            }
        }
    }
}

private enum class Screen { MAIN, NEW_GAME, SETTINGS }

@Composable
private fun WearRoot() {
    val state = LocalWear.current
    var screen by remember { mutableStateOf(Screen.MAIN) }
    Box(Modifier.fillMaxSize().background(Color.Black)) {
        if (screen == Screen.MAIN) {
            Main(onNewGame = { screen = Screen.NEW_GAME }, onSettings = { screen = Screen.SETTINGS })
        } else {
            // Swipe right to go back.
            SwipeToDismissBox(onDismissed = { screen = Screen.MAIN }) { isBackground ->
                when {
                    isBackground -> Box(Modifier.fillMaxSize().background(Color.Black))
                    screen == Screen.NEW_GAME -> NewGame(onStart = {
                        state.engine.newGame("Away", "Home", rememberNames = false)
                        screen = Screen.MAIN
                    })
                    else -> Settings()
                }
            }
        }
    }
}

@Composable
private fun Main(onNewGame: () -> Unit, onSettings: () -> Unit) {
    val g = LocalWear.current.game
    if (g != null && !g.finished) {
        // Swipe up and down between the pages.
        val pager = rememberPagerState { 4 }
        VerticalPager(pager, Modifier.fillMaxSize()) { page ->
            when (page) {
                0 -> ClockPage(g)
                1 -> ScorePage(g)
                2 -> TallyPage(g)
                else -> ControlsPage(g, onSettings)
            }
        }
    } else {
        StartPage(g, onNewGame, onSettings)
    }
}

/** Keeps content inside the visible area of a round screen. */
@Composable
private fun inset(fraction: Float): Dp {
    val config = LocalConfiguration.current
    return if (config.isScreenRound) (config.screenWidthDp * fraction).dp else 6.dp
}

// ---------------------------------------------------------------- start / finished / new game

@Composable
private fun StartPage(finished: Game?, onNewGame: () -> Unit, onSettings: () -> Unit) {
    val state = LocalWear.current
    val s = state.settings
    ScalingLazyColumn(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
        if (finished != null) {
            item { Text(finished.resultText, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center) }
            inningLines(finished)
        } else {
            item { Text("Indoor Softball", fontWeight = FontWeight.Bold) }
            item { Text("${s.scoring.title} · ${s.innings} inn × ${durationText(s.halfInningSeconds)}", color = Secondary, fontSize = 12.sp) }
        }
        item { Chip(onClick = onNewGame, label = { Text("New Game") }, colors = ChipDefaults.primaryChipColors(backgroundColor = Positive, contentColor = Color.Black), modifier = Modifier.fillMaxWidth()) }
        item { Chip(onClick = onSettings, label = { Text("Settings") }, colors = ChipDefaults.secondaryChipColors(), modifier = Modifier.fillMaxWidth()) }
        if (finished != null) {
            item { Chip(onClick = { state.engine.closeFinishedGame() }, label = { Text("Close") }, colors = ChipDefaults.secondaryChipColors(), modifier = Modifier.fillMaxWidth()) }
        }
    }
}

/** Each inning's plus / minus / total per team, then the running score. */
private fun ScalingLazyListScope.inningLines(g: Game) {
    for (inning in 1..g.inningsCount) {
        item {
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(Color(0xFF212121)).padding(8.dp)) {
                Text("Inning $inning", color = Secondary, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                for (team in Team.entries) {
                    val h = g.half(team, inning) ?: continue
                    Row {
                        Text(g.name(team), Modifier.weight(1f), color = teamColor(team), fontSize = 12.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        if (g.isReached(h)) {
                            Text("+${h.positive} ${if (h.negative == 0) "−0" else h.negative.signed()} = ${h.net.score()}", fontSize = 12.sp)
                        } else {
                            Text("not played", color = Secondary, fontSize = 12.sp)
                        }
                    }
                }
                val bottom = g.half(Team.HOME, inning)
                if (bottom != null && g.isReached(bottom)) {
                    Text("After $inning: ${g.cumulative(Team.AWAY, inning).score()} – ${g.cumulative(Team.HOME, inning).score()}",
                        color = Secondary, fontSize = 11.sp)
                }
            }
        }
    }
}

/** New game on the watch: always Away v Home; add the teams and location on the phone afterwards. */
@Composable
private fun NewGame(onStart: () -> Unit) {
    val state = LocalWear.current
    val s = state.settings
    ScalingLazyColumn(Modifier.fillMaxSize().background(Color.Black), horizontalAlignment = Alignment.CenterHorizontally) {
        item {
            Row {
                Text("Away", color = Away, fontWeight = FontWeight.Bold)
                Text(" v ", color = Secondary)
                Text("Home", color = Home, fontWeight = FontWeight.Bold)
            }
        }
        item { OutdoorToggle(s) { state.engine.settings = it } }
        item { Text("${s.innings} innings · ${durationText(s.halfInningSeconds)} halves", color = Secondary, fontSize = 12.sp) }
        item { Chip(onClick = onStart, label = { Text("Start") }, colors = ChipDefaults.primaryChipColors(backgroundColor = Positive, contentColor = Color.Black), modifier = Modifier.fillMaxWidth()) }
        item { Text("Add team names afterwards in History on your phone.", color = Secondary, fontSize = 11.sp, textAlign = TextAlign.Center) }
    }
}

@Composable
private fun OutdoorToggle(s: GameSettings, onChange: (GameSettings) -> Unit) {
    val outdoor = s.scoring == ScoringType.OUTDOOR
    ToggleChip(
        checked = outdoor,
        onCheckedChange = { onChange(s.copy(scoring = if (it) ScoringType.OUTDOOR else ScoringType.INDOOR)) },
        label = { Text("Outdoor scoring") },
        toggleControl = { Icon(ToggleChipDefaults.switchIcon(outdoor), if (outdoor) "On" else "Off") },
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun Settings() {
    val state = LocalWear.current
    val s = state.settings
    fun set(new: GameSettings) { state.engine.settings = new.sanitized() }
    ScalingLazyColumn(Modifier.fillMaxSize().background(Color.Black), horizontalAlignment = Alignment.CenterHorizontally) {
        item { Text("Settings", fontWeight = FontWeight.Bold) }
        item { OutdoorToggle(s, ::set) }
        item { Stepper("Innings", "${s.innings}") { set(s.copy(innings = s.innings + it)) } }
        item { Stepper("Time per half", durationText(s.halfInningSeconds)) { set(s.copy(halfInningSeconds = s.halfInningSeconds + it * GameSettings.HALF_STEP)) } }
        item { Stepper("Warning at", if (s.warningSeconds == 0) "Off" else durationText(s.warningSeconds)) { set(s.copy(warningSeconds = s.warningSeconds + it * GameSettings.WARNING_STEP)) } }
        if (s.scoring == ScoringType.INDOOR) {
            item { Stepper("Home run (HR)", s.homeRunPoints.signed()) { set(s.copy(homeRunPoints = s.homeRunPoints + it)) } }
            item { Stepper("Catcher out (OC)", s.outAtHomeByCatcherPoints.signed()) { set(s.copy(outAtHomeByCatcherPoints = s.outAtHomeByCatcherPoints + it)) } }
        }
        item { Text("Version ${BuildConfig.VERSION_NAME}\n© 2026 NetTek Ltd", color = Secondary, fontSize = 11.sp, textAlign = TextAlign.Center) }
    }
}

@Composable
private fun Stepper(title: String, value: String, onStep: (Int) -> Unit) =
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color(0xFF212121)).padding(horizontal = 8.dp, vertical = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally) {
        Text(title, color = Secondary, fontSize = 11.sp)
        Row(verticalAlignment = Alignment.CenterVertically) {
            Pad("−", Color.White, 20.sp, Modifier.size(40.dp, 34.dp)) { onStep(-1) }
            Text(value, Modifier.weight(1f), fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
            Pad("+", Color.White, 20.sp, Modifier.size(40.dp, 34.dp)) { onStep(1) }
        }
    }

// ---------------------------------------------------------------- page 1: clock

@Composable
private fun ClockPage(g: Game) {
    val state = LocalWear.current
    val engine = state.engine
    val now = state.now
    val status = engine.clockStatus(now)
    val color = clockColor(status)
    val timer = g.current.timer
    val timeUp = status == ClockStatus.TIME_UP
    Column(
        Modifier.fillMaxSize().background(if (timeUp) Negative.copy(alpha = 0.35f) else color.copy(alpha = 0.12f))
            .padding(horizontal = inset(0.10f), vertical = inset(0.08f)),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.SpaceEvenly,
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.padding(horizontal = inset(0.11f))) {
            for (team in Team.entries) {
                val batting = g.current.battingTeam == team
                val shape = RoundedCornerShape(8.dp)
                Column(
                    Modifier.weight(1f).clip(shape).background(teamColor(team).copy(alpha = if (batting) 0.45f else 0.12f))
                        .border(if (batting) 1.5.dp else 0.dp, if (batting) teamColor(team) else Color.Transparent, shape),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(g.name(team), fontSize = 10.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
                    Text(g.total(team).score(), fontSize = 18.sp, fontWeight = FontWeight.Black)
                }
            }
        }
        Text(if (timeUp) "TIME – ${g.current.label}" else g.current.label, fontSize = 11.sp, fontWeight = FontWeight.Bold,
            color = if (timeUp) Negative else Secondary)
        val flash = timeUp && (now / 550) % 2 == 0L
        Text(clockText(engine.remaining(now)), fontSize = 44.sp, fontWeight = FontWeight.Black, color = color,
            maxLines = 1, modifier = Modifier.alpha(if (flash) 0.35f else 1f))
        Box(Modifier.fillMaxWidth().height(5.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.12f))) {
            Box(Modifier.fillMaxWidth(timer.progress(now)).fillMaxHeight().background(color))
        }
        if (timeUp) {
            // The half is over: scores can still be entered until this is tapped.
            Pad(if (g.isLastHalf) "End Game" else "Start ${g.halves[g.currentIndex + 1].shortLabel}", Color.White, 15.sp,
                Modifier.fillMaxWidth(0.8f).height(36.dp), fill = Negative) {
                if (g.isLastHalf) engine.finishGame() else engine.startNextHalfAndClock()
            }
        } else {
            Pad(if (timer.isRunning) "Pause" else if (timer.hasStarted) "Resume" else "Start", Color.Black, 15.sp,
                Modifier.fillMaxWidth(0.7f).height(36.dp), fill = if (timer.isRunning) Warning else Positive) { engine.toggleClock() }
        }
    }
}

// ---------------------------------------------------------------- page 2: scoring

/**
 * Indoor: tallies, +1 and −1, then HR, OC and Undo.
 * Outdoor: runs, +1 with Undo, then HR+1, HR+2 and HR+3.
 */
@Composable
private fun ScorePage(g: Game) {
    val state = LocalWear.current
    val engine = state.engine
    val h = g.current
    val outdoor = g.settings.scoring == ScoringType.OUTDOOR
    val timeUp = engine.clockStatus(state.now) == ClockStatus.TIME_UP
    Column(
        Modifier.fillMaxSize().padding(top = inset(0.07f), bottom = inset(0.12f)),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Row(Modifier.padding(horizontal = inset(0.20f)), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            if (outdoor) {
                Text("Runs ${h.net.score()}", fontWeight = FontWeight.Black, color = pointsColor(h.net), fontSize = 15.sp)
            } else {
                Text("+${h.positive}", fontWeight = FontWeight.Black, color = Positive, fontSize = 15.sp)
                Text(if (h.negative == 0) "−0" else h.negative.signed(), fontWeight = FontWeight.Black, color = Negative, fontSize = 15.sp)
                Text("= ${h.net.score()}", fontWeight = FontWeight.Black, color = pointsColor(h.net), fontSize = 15.sp)
            }
        }
        if (timeUp) Text("TIME – still scoring ${h.shortLabel}", color = Negative, fontSize = 10.sp, fontWeight = FontWeight.Bold)
        Row(Modifier.weight(1f).padding(horizontal = inset(0.09f)), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            Pad("+1", Positive, 32.sp, Modifier.weight(1f).fillMaxHeight()) { engine.record(EventKind.PLUS) }
            if (outdoor) {
                Pad("↩", Color(0xFFBBBBBB), 20.sp, Modifier.width(44.dp).fillMaxHeight(), "Undo last", engine.canUndo) { engine.undo() }
            } else {
                Pad("−1", Negative, 32.sp, Modifier.weight(1f).fillMaxHeight()) { engine.record(EventKind.MINUS) }
            }
        }
        // The lower row sits where a round screen is narrower, so it is inset further.
        Row(Modifier.height(38.dp).padding(horizontal = inset(0.17f)), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            if (outdoor) {
                for (n in 1..3) {
                    Pad("HR+$n", Warning, 13.sp, Modifier.weight(1f).fillMaxHeight(), "Home run plus $n, ${n + 1} runs") {
                        engine.record(EventKind.HOME_RUN, runnersOn = n)
                    }
                }
            } else {
                Pad("HR ${g.settings.homeRunPoints.signed()}", Warning, 12.sp, Modifier.weight(1f).fillMaxHeight(), "Home run") {
                    engine.record(EventKind.HOME_RUN)
                }
                Pad("OC ${g.settings.outAtHomeByCatcherPoints.signed()}", Negative, 12.sp, Modifier.weight(1f).fillMaxHeight(), "Out by catcher at home") {
                    engine.record(EventKind.OUT_BY_CATCHER)
                }
                Pad("↩", Color(0xFFBBBBBB), 16.sp, Modifier.width(30.dp).fillMaxHeight(), "Undo last", engine.canUndo) { engine.undo() }
            }
        }
    }
}

@Composable
private fun Pad(
    title: String, color: Color, fontSize: TextUnit, modifier: Modifier, description: String? = null,
    enabled: Boolean = true, fill: Color? = null, onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(12.dp)
    Box(
        modifier
            .clip(shape)
            .background(fill ?: color.copy(alpha = 0.16f))
            .border(1.2.dp, if (fill != null) Color.Transparent else color.copy(alpha = 0.55f), shape)
            .alpha(if (enabled) 1f else 0.4f)
            .clickable(enabled = enabled, onClick = onClick)
            .semantics { contentDescription = description ?: title },
        contentAlignment = Alignment.Center,
    ) {
        Text(title, color = color, fontSize = fontSize, fontWeight = FontWeight.Black, maxLines = 1, softWrap = false)
    }
}

// ---------------------------------------------------------------- page 3: tallies

@Composable
private fun TallyPage(g: Game) =
    ScalingLazyColumn(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
        item { Text("${g.awayName} ${g.total(Team.AWAY).score()} – ${g.homeName} ${g.total(Team.HOME).score()}", fontWeight = FontWeight.Bold, maxLines = 1) }
        inningLines(g)
    }

// ---------------------------------------------------------------- page 4: controls

@Composable
private fun ControlsPage(g: Game, onSettings: () -> Unit) {
    val state = LocalWear.current
    val engine = state.engine
    // Ending a half early or discarding needs a second tap.
    var armed by remember { mutableStateOf<String?>(null) }
    val timeUp = engine.clockStatus(state.now) == ClockStatus.TIME_UP
    ScalingLazyColumn(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
        item {
            val next = if (g.isLastHalf) "End Game" else "Start ${g.halves[g.currentIndex + 1].label}"
            Chip(
                onClick = {
                    if (timeUp || armed == "next") {
                        armed = null
                        if (g.isLastHalf) engine.finishGame() else if (timeUp) engine.startNextHalfAndClock() else engine.startNextHalf()
                    } else armed = "next"
                },
                label = { Text(if (armed == "next") "Tap again – ${clockText(engine.remaining(state.now))} left" else next) },
                colors = if (timeUp || armed == "next") ChipDefaults.primaryChipColors(backgroundColor = Negative) else ChipDefaults.secondaryChipColors(),
                modifier = Modifier.fillMaxWidth(),
            )
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Pad("−30s", Color.White, 14.sp, Modifier.size(70.dp, 36.dp)) { engine.addTime(-30) }
                Pad("+30s", Color.White, 14.sp, Modifier.size(70.dp, 36.dp)) { engine.addTime(30) }
            }
        }
        item { Chip(onClick = onSettings, label = { Text("Settings") }, colors = ChipDefaults.secondaryChipColors(), modifier = Modifier.fillMaxWidth()) }
        if (!g.isLastHalf) {
            item {
                Chip(
                    onClick = { if (armed == "end") { armed = null; engine.finishGame() } else armed = "end" },
                    label = { Text(if (armed == "end") "Tap again to end game" else "End game now") },
                    colors = ChipDefaults.secondaryChipColors(), modifier = Modifier.fillMaxWidth(),
                )
            }
        }
        item {
            Chip(
                onClick = { if (armed == "discard") { armed = null; engine.discardGame() } else armed = "discard" },
                label = { Text(if (armed == "discard") "Tap again to discard" else "Discard game", color = Negative) },
                colors = ChipDefaults.secondaryChipColors(), modifier = Modifier.fillMaxWidth(),
            )
        }
        item { Spacer(Modifier.height(8.dp)) }
    }
}
