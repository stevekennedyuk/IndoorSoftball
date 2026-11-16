@file:OptIn(ExperimentalMaterial3Api::class)

package uk.nettek.indoorsoftball.ui

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import uk.nettek.indoorsoftball.shared.ClockStatus
import uk.nettek.indoorsoftball.shared.Game
import uk.nettek.indoorsoftball.shared.GameSettings
import uk.nettek.indoorsoftball.shared.ScoringType
import uk.nettek.indoorsoftball.shared.clockText
import uk.nettek.indoorsoftball.shared.durationText
import uk.nettek.indoorsoftball.shared.exportFileName
import uk.nettek.indoorsoftball.shared.signed

/** The Game tab: start screen, live scoring, or the finished-game summary. */
@Composable
fun GameTab() {
    val app = LocalApp.current
    var showNewGame by rememberSaveable { mutableStateOf(false) }
    val game = app.game
    when {
        showNewGame -> NewGameScreen(onDone = { showNewGame = false })
        game == null -> StartScreen(onNewGame = { showNewGame = true })
        game.finished -> FinishedScreen(game, onNewGame = { showNewGame = true })
        else -> LiveScreen(game, onNewGame = { showNewGame = true })
    }
}

// ---------------------------------------------------------------- start

@Composable
private fun StartScreen(onNewGame: () -> Unit) {
    val s = LocalApp.current.settings
    Scaffold(topBar = { TopAppBar(title = { Text("Indoor Softball") }) }) { pad ->
        Column(
            Modifier.padding(pad).fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            Text("Timed half innings · indoor or outdoor scoring", color = Palette.Secondary, textAlign = TextAlign.Center)
            Card(Modifier.widthIn(max = 480.dp).fillMaxWidth()) {
                SummaryRow("Scoring", s.scoring.title)
                SummaryRow("Innings", "${s.innings}")
                SummaryRow("Time per half", durationText(s.halfInningSeconds))
                if (s.scoring == ScoringType.INDOOR) {
                    SummaryRow("Home run (HR)", s.homeRunPoints.signed())
                    SummaryRow("Out by catcher at home (OC)", s.outAtHomeByCatcherPoints.signed())
                }
            }
            Button(onClick = onNewGame, Modifier.widthIn(max = 480.dp).fillMaxWidth().height(56.dp)) {
                Text("▶  New Game", fontSize = 20.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
private fun SummaryRow(title: String, value: String) = Row(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
    Text(title, Modifier.weight(1f), color = Palette.Secondary)
    Text(value, fontWeight = FontWeight.SemiBold)
}

// ---------------------------------------------------------------- new game

@Composable
private fun NewGameScreen(onDone: () -> Unit) {
    val app = LocalApp.current
    val context = LocalContext.current
    var draft by remember { mutableStateOf(app.settings) }
    var away by rememberSaveable { mutableStateOf(app.settings.awayName) }
    var home by rememberSaveable { mutableStateOf(app.settings.homeName) }
    var location by rememberSaveable { mutableStateOf(app.settings.location) }
    val askNotifications = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {}
    BackHandler(onBack = onDone)

    fun start() {
        app.engine.settings = draft
        app.engine.newGame(away, home, location)
        // Ask once the user has started a game, so the reason is obvious.
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) askNotifications.launch(Manifest.permission.POST_NOTIFICATIONS)
        onDone()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("New Game") },
                navigationIcon = { TextButton(onClick = onDone) { Text("Cancel") } },
                actions = { TextButton(onClick = ::start) { Text("Start", fontWeight = FontWeight.Bold) } },
            )
        },
    ) { pad ->
        Column(
            Modifier.padding(pad).fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            val current = app.game
            if (current != null && !current.finished) {
                Text("Starting a new game abandons the game in progress (${current.awayName} v ${current.homeName}).",
                    color = Palette.Warning, fontSize = 13.sp)
            }
            OutlinedTextField(away, { away = it }, Modifier.fillMaxWidth(), singleLine = true, label = { Text("Away team (bats first)") })
            OutlinedTextField(home, { home = it }, Modifier.fillMaxWidth(), singleLine = true, label = { Text("Home team") })
            OutlinedTextField(location, { location = it }, Modifier.fillMaxWidth(), singleLine = true, label = { Text("Location (optional)") })
            SettingsFields(draft) { draft = it }
            Button(onClick = ::start, Modifier.fillMaxWidth().height(52.dp)) {
                Text("▶  Start", fontSize = 18.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}

// ---------------------------------------------------------------- live

/**
 * Live scoring, laid out to fit the screen without scrolling. The layout is
 * chosen from the space available (same thresholds as the iOS app):
 * - Wide and tall enough (tablets, ≥ 900 × 600 dp): two large columns with a
 *   clock that fills its column and the line score.
 * - Landscape otherwise: two compact columns.
 * - Portrait: one column; compact when short (folded phones), large on tall tablets.
 */
@Composable
private fun LiveScreen(g: Game, onNewGame: () -> Unit) {
    val app = LocalApp.current
    val engine = app.engine
    var menu by remember { mutableStateOf(false) }
    var showScores by remember { mutableStateOf(false) }
    var confirm by remember { mutableStateOf<String?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(g.current.label) },
                actions = {
                    IconButton(onClick = { showScores = true }) { Icon(Icons.AutoMirrored.Filled.List, "Scores so far") }
                    IconButton(onClick = { menu = true }) { Icon(Icons.Default.MoreVert, "More") }
                    DropdownMenu(menu, onDismissRequest = { menu = false }) {
                        DropdownMenuItem(
                            text = { Text(if (g.isLastHalf) "End game" else "End ${g.current.label} now") },
                            onClick = { menu = false; confirm = "half" },
                        )
                        DropdownMenuItem(text = { Text("Scores so far") }, onClick = { menu = false; showScores = true })
                        HorizontalDivider()
                        DropdownMenuItem(text = { Text("New game…") }, onClick = { menu = false; onNewGame() })
                        DropdownMenuItem(text = { Text("End game now") }, onClick = { menu = false; confirm = "game" })
                        DropdownMenuItem(text = { Text("Discard game", color = Palette.Negative) }, onClick = { menu = false; confirm = "discard" })
                    }
                },
            )
        },
    ) { pad ->
        BoxWithConstraints(Modifier.padding(pad).fillMaxSize()) {
            val w = maxWidth
            val h = maxHeight
            when {
                w >= 900.dp && h >= 600.dp -> Row(Modifier.fillMaxSize().padding(20.dp), horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                    Column(Modifier.weight(1f).fillMaxHeight(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        ScoreHeader(g, PanelSize.LARGE)
                        ClockCard(g, PanelSize.LARGE, Modifier.weight(1f).fillMaxWidth(), expand = true)
                        LineScore(g, Modifier.fillMaxWidth())
                    }
                    // Half the width, capped so the buttons don't sprawl on big tablets.
                    Column(Modifier.width(minOf(560.dp, (w - 60.dp) / 2)).fillMaxHeight(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        TallyBar(g, PanelSize.LARGE)
                        ScoringPad(g, PanelSize.LARGE, Modifier.weight(1f))
                    }
                }
                w > h -> Row(Modifier.fillMaxSize().padding(10.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        ScoreHeader(g, PanelSize.COMPACT)
                        ClockCard(g, PanelSize.COMPACT, Modifier.fillMaxWidth())
                    }
                    Column(Modifier.weight(1f).fillMaxHeight(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        TallyBar(g, PanelSize.COMPACT)
                        ScoringPad(g, PanelSize.COMPACT, Modifier.weight(1f))
                    }
                }
                else -> {
                    val size = when {
                        w >= 600.dp && h >= 900.dp -> PanelSize.LARGE
                        h < 540.dp -> PanelSize.COMPACT
                        else -> PanelSize.REGULAR
                    }
                    Column(
                        Modifier.fillMaxSize().padding(horizontal = if (size == PanelSize.LARGE) 24.dp else 14.dp, vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(if (size == PanelSize.COMPACT) 8.dp else 10.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        val width = Modifier.widthIn(max = 720.dp).fillMaxWidth()
                        Column(width) { ScoreHeader(g, size) }
                        ClockCard(g, size, width)
                        Column(width) { TallyBar(g, size) }
                        ScoringPad(g, size, width.weight(1f))
                    }
                }
            }
        }
    }

    if (showScores) {
        ModalBottomSheet(onDismissRequest = { showScores = false }) {
            Column(Modifier.verticalScroll(rememberScrollState()).padding(16.dp)) { GameSummary(g) }
        }
    }

    when (confirm) {
        "half" -> {
            val timeUp = engine.clockStatus(app.now) == ClockStatus.TIME_UP
            val left = if (g.current.timer.hasStarted) "${clockText(engine.remaining(app.now))} left on the clock." else "The clock hasn't been started."
            ConfirmDialog(
                title = if (timeUp) (if (g.isLastHalf) "End the game?" else "Start ${g.halves[g.currentIndex + 1].label}?") else "Time isn't up yet",
                text = "$left ${g.current.label} scores will be locked.",
                action = if (g.isLastHalf) "End game" else "End ${g.current.label}",
                onDismiss = { confirm = null },
            ) { if (g.isLastHalf) engine.finishGame() else engine.startNextHalf() }
        }
        "game" -> ConfirmDialog("End the game now?", "Unplayed halves will be left blank.", "End game", { confirm = null }) { engine.finishGame() }
        "discard" -> ConfirmDialog("Discard this game?", "It won't be saved to History.", "Discard", { confirm = null }) { engine.discardGame() }
    }
}

@Composable
fun ConfirmDialog(title: String, text: String, action: String, onDismiss: () -> Unit, onConfirm: () -> Unit) =
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = { Text(text) },
        confirmButton = { TextButton(onClick = { onDismiss(); onConfirm() }) { Text(action) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )

// ---------------------------------------------------------------- finished

@Composable
private fun FinishedScreen(g: Game, onNewGame: () -> Unit) {
    val app = LocalApp.current
    var editing by remember { mutableStateOf(false) }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Final") },
                navigationIcon = { TextButton(onClick = { app.engine.closeFinishedGame() }) { Text("Close") } },
                actions = { ResultActions(g, onEdit = { editing = true }) },
            )
        },
    ) { pad ->
        Column(
            Modifier.padding(pad).fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(Modifier.widthIn(max = 900.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                GameSummary(g)
                ShareButton(g)
                Text("Saved as \"${g.exportFileName()}\". Use Share results to send it, or Save a copy in the menu.",
                    color = Palette.Secondary, fontSize = 12.sp, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
                Button(onClick = onNewGame, Modifier.fillMaxWidth().height(52.dp)) {
                    Text("▶  New Game", fontSize = 18.sp, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
    if (editing) EditDetailsDialog(g) { editing = false }
}

@Composable
fun ShareButton(g: Game) {
    val app = LocalApp.current
    Button(
        onClick = { app.archive.share(g) },
        colors = ButtonDefaults.buttonColors(containerColor = Palette.Away, contentColor = androidx.compose.ui.graphics.Color.White),
        modifier = Modifier.fillMaxWidth().height(52.dp),
    ) {
        Icon(Icons.Default.Share, null)
        Text("  Share results", fontSize = 18.sp, fontWeight = FontWeight.Bold)
    }
}

/** Top-bar actions for a finished game: share, edit teams and location, save a copy. */
@Composable
fun ResultActions(g: Game, onEdit: () -> Unit, extra: @Composable (dismiss: () -> Unit) -> Unit = {}) {
    val app = LocalApp.current
    var menu by remember { mutableStateOf(false) }
    val saveCopy = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/plain")) { uri ->
        if (uri != null) app.archive.saveCopy(g, uri)
    }
    IconButton(onClick = { app.archive.share(g) }) { Icon(Icons.Default.Share, "Share results") }
    IconButton(onClick = onEdit) { Icon(Icons.Default.Edit, "Edit teams and location") }
    IconButton(onClick = { menu = true }) { Icon(Icons.Default.MoreVert, "More") }
    DropdownMenu(menu, onDismissRequest = { menu = false }) {
        DropdownMenuItem(text = { Text("Save a copy…") }, onClick = { menu = false; saveCopy.launch(g.exportFileName()) })
        extra { menu = false }
    }
}

/** Change the teams and location of a finished game; its results file is renamed to match. */
@Composable
fun EditDetailsDialog(g: Game, onDismiss: () -> Unit) {
    val engine = LocalApp.current.engine
    var home by remember { mutableStateOf(g.homeName) }
    var away by remember { mutableStateOf(g.awayName) }
    var location by remember { mutableStateOf(g.location ?: "") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Game details") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(home, { home = it }, singleLine = true, label = { Text("Home team") })
                OutlinedTextField(away, { away = it }, singleLine = true, label = { Text("Away team") })
                OutlinedTextField(location, { location = it }, singleLine = true, label = { Text("Location") })
                Text("The saved results file is renamed to match.", color = Palette.Secondary, fontSize = 12.sp)
            }
        },
        confirmButton = { TextButton(onClick = { engine.updateDetails(g.id, away, home, location); onDismiss() }) { Text("Save") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

// ---------------------------------------------------------------- settings fields

/** Scoring type, innings, time and the indoor values. Used in New Game and Settings. */
@Composable
fun SettingsFields(s: GameSettings, onChange: (GameSettings) -> Unit) {
    Card(Modifier.fillMaxWidth()) {
        Label("SCORING TYPE")
        Row(Modifier.fillMaxWidth().padding(top = 6.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            for (type in ScoringType.entries) {
                val selected = s.scoring == type
                if (selected) {
                    Button(onClick = {}, Modifier.weight(1f)) { Text(type.title, fontWeight = FontWeight.Bold) }
                } else {
                    OutlinedButton(onClick = { onChange(s.copy(scoring = type)) }, Modifier.weight(1f)) { Text(type.title) }
                }
            }
        }
        Text(
            if (s.scoring == ScoringType.INDOOR) "Indoor: +1, −1, HR (home run off the back wall) and OC (out by the catcher at home)."
            else "Outdoor: runs only. +1 for a run, and HR+1, HR+2 or HR+3 for a home run with 1, 2 or 3 runners on (2, 3 or 4 runs).",
            color = Palette.Secondary, fontSize = 12.sp, modifier = Modifier.padding(top = 8.dp),
        )
    }
    Card(Modifier.fillMaxWidth()) {
        Label("GAME")
        Stepper("Innings", "${s.innings}", s.innings > GameSettings.INNINGS_RANGE.first, s.innings < GameSettings.INNINGS_RANGE.last) {
            onChange(s.copy(innings = s.innings + it))
        }
        Stepper("Time per half", durationText(s.halfInningSeconds),
            s.halfInningSeconds > GameSettings.HALF_RANGE.first, s.halfInningSeconds < GameSettings.HALF_RANGE.last) {
            onChange(s.copy(halfInningSeconds = s.halfInningSeconds + it * GameSettings.HALF_STEP))
        }
        Stepper("Warning at", if (s.warningSeconds == 0) "Off" else "${durationText(s.warningSeconds)} left",
            s.warningSeconds > GameSettings.WARNING_RANGE.first, s.warningSeconds < GameSettings.WARNING_RANGE.last) {
            onChange(s.copy(warningSeconds = s.warningSeconds + it * GameSettings.WARNING_STEP))
        }
    }
    if (s.scoring == ScoringType.INDOOR) {
        Card(Modifier.fillMaxWidth()) {
            Label("INDOOR SCORING")
            Stepper("Home run (HR)", s.homeRunPoints.signed(),
                s.homeRunPoints > GameSettings.HOME_RUN_RANGE.first, s.homeRunPoints < GameSettings.HOME_RUN_RANGE.last) {
                onChange(s.copy(homeRunPoints = s.homeRunPoints + it))
            }
            Stepper("Out by catcher at home (OC)", s.outAtHomeByCatcherPoints.signed(),
                s.outAtHomeByCatcherPoints > GameSettings.OUT_RANGE.first, s.outAtHomeByCatcherPoints < GameSettings.OUT_RANGE.last) {
                onChange(s.copy(outAtHomeByCatcherPoints = s.outAtHomeByCatcherPoints + it))
            }
        }
    }
}

@Composable
private fun Stepper(title: String, value: String, canDown: Boolean, canUp: Boolean, onStep: (Int) -> Unit) =
    Row(Modifier.fillMaxWidth().padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(title, Modifier.weight(1f))
        Text(value, Modifier.padding(end = 10.dp), fontWeight = FontWeight.SemiBold, color = Palette.Secondary)
        OutlinedButton(onClick = { onStep(-1) }, enabled = canDown) { Text("−", fontSize = 18.sp) }
        Spacer(Modifier.padding(start = 6.dp))
        OutlinedButton(onClick = { onStep(1) }, enabled = canUp) { Text("+", fontSize = 18.sp) }
    }
