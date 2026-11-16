@file:OptIn(ExperimentalMaterial3Api::class)

package uk.nettek.indoorsoftball.ui

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import uk.nettek.indoorsoftball.BuildConfig
import uk.nettek.indoorsoftball.R
import uk.nettek.indoorsoftball.shared.Game
import uk.nettek.indoorsoftball.shared.GameSettings
import uk.nettek.indoorsoftball.shared.Team
import uk.nettek.indoorsoftball.shared.score

/** Game, History and Settings tabs. */
@Composable
fun Root() {
    var tab by rememberSaveable { mutableIntStateOf(0) }
    Scaffold(
        bottomBar = {
            NavigationBar {
                NavigationBarItem(tab == 0, { tab = 0 }, icon = { Icon(Icons.Default.Home, null) }, label = { Text("Game") })
                NavigationBarItem(tab == 1, { tab = 1 }, icon = { Icon(Icons.AutoMirrored.Filled.List, null) }, label = { Text("History") })
                NavigationBarItem(tab == 2, { tab = 2 }, icon = { Icon(Icons.Default.Settings, null) }, label = { Text("Settings") })
            }
        },
    ) { pad ->
        // Each tab draws its own top bar; only the bottom bar's space is reserved here.
        Box(Modifier.padding(bottom = pad.calculateBottomPadding()).fillMaxSize()) {
            when (tab) {
                0 -> GameTab()
                1 -> HistoryTab()
                else -> SettingsTab()
            }
        }
    }
}

// ---------------------------------------------------------------- history

@Composable
private fun HistoryTab() {
    val app = LocalApp.current
    var openId by rememberSaveable { mutableStateOf<String?>(null) }
    val open = app.history.firstOrNull { it.id == openId }
    if (open != null) {
        GameDetailScreen(open) { openId = null }
        return
    }
    Scaffold(topBar = { TopAppBar(title = { Text("History") }) }) { pad ->
        if (app.history.isEmpty()) {
            Column(Modifier.padding(pad).fillMaxSize().padding(32.dp), Arrangement.Center, Alignment.CenterHorizontally) {
                Text("No games yet", fontSize = 22.sp, fontWeight = FontWeight.Bold)
                Text("Finished games – from this device or your watch – appear here.", color = Palette.Secondary, textAlign = TextAlign.Center)
            }
        } else {
            LazyColumn(Modifier.padding(pad).fillMaxSize()) {
                items(app.history, key = { it.id }) { g -> HistoryRow(g) { openId = g.id } }
            }
        }
    }
}

@Composable
private fun HistoryRow(g: Game, onClick: () -> Unit) =
    Column(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = 16.dp, vertical = 10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            for (team in Team.entries) {
                if (team == Team.HOME) Text("  –  ", color = Palette.Secondary)
                Text(g.name(team) + (if (g.winner == team) " ★" else ""), fontWeight = FontWeight.SemiBold, maxLines = 1,
                    overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                Text(" " + g.total(team).score(), fontWeight = FontWeight.Black, color = Palette.team(team))
            }
        }
        Text(
            listOfNotNull(
                formatDateTime(g.playStart), g.location,
                g.scoredOn.takeIf { it.isNotEmpty() && !g.isFromWatch },
                "tie".takeIf { g.winner == null },
            ).joinToString(" · "),
            color = Palette.Secondary, fontSize = 12.sp, maxLines = 1, overflow = TextOverflow.Ellipsis,
        )
        if (g.isFromWatch) {
            Text(
                if (g.needsDetails) "Scored on watch · tap to add teams & location" else "Scored on watch",
                color = if (g.needsDetails) Palette.Warning else Palette.Secondary, fontSize = 12.sp,
                fontWeight = if (g.needsDetails) FontWeight.SemiBold else FontWeight.Normal,
            )
        }
    }

@Composable
private fun GameDetailScreen(g: Game, onBack: () -> Unit) {
    val app = LocalApp.current
    var editing by remember { mutableStateOf(false) }
    var deleting by remember { mutableStateOf(false) }
    BackHandler(onBack = onBack)
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("${g.awayName} v ${g.homeName}", maxLines = 1, overflow = TextOverflow.Ellipsis) },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back") } },
                actions = {
                    ResultActions(g, onEdit = { editing = true }) { dismiss ->
                        DropdownMenuItem(text = { Text("Delete game…", color = Palette.Negative) }, onClick = { dismiss(); deleting = true })
                    }
                },
            )
        },
    ) { pad ->
        Column(
            Modifier.padding(pad).fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(Modifier.widthIn(max = 900.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                if (g.isFromWatch) {
                    // Games from the watch are Away v Home: make adding the details obvious.
                    val shape = RoundedCornerShape(14.dp)
                    val color = if (g.needsDetails) Palette.Warning else Color.White
                    Column(
                        Modifier.fillMaxWidth().clip(shape)
                            .background(if (g.needsDetails) Palette.Warning.copy(alpha = 0.18f) else Palette.Card)
                            .border(1.5.dp, if (g.needsDetails) Palette.Warning else Color.Transparent, shape)
                            .clickable { editing = true }.padding(14.dp),
                    ) {
                        Text(if (g.needsDetails) "Add team names & location" else "Edit teams & location", color = color, fontWeight = FontWeight.Bold)
                        Text("Scored on the watch. The results file is renamed to match.", color = Palette.Secondary, fontSize = 12.sp)
                    }
                }
                GameSummary(g)
                ShareButton(g)
            }
        }
    }
    if (editing) EditDetailsDialog(g) { editing = false }
    if (deleting) {
        AlertDialog(
            onDismissRequest = { deleting = false },
            title = { Text("Delete this game?") },
            text = { Text("You can also keep its saved results file.") },
            confirmButton = {
                Column(horizontalAlignment = Alignment.End) {
                    TextButton(onClick = { deleting = false; app.engine.deleteHistory(setOf(g.id), deleteFiles = true); onBack() }) {
                        Text("Delete game and results file", color = Palette.Negative)
                    }
                    TextButton(onClick = { deleting = false; app.engine.deleteHistory(setOf(g.id), deleteFiles = false); onBack() }) {
                        Text("Delete from History, keep file")
                    }
                    TextButton(onClick = { deleting = false }) { Text("Cancel") }
                }
            },
        )
    }
}

// ---------------------------------------------------------------- settings

@Composable
private fun SettingsTab() {
    val app = LocalApp.current
    var about by rememberSaveable { mutableStateOf(false) }
    if (about) {
        AboutScreen { about = false }
        return
    }
    Scaffold(topBar = { TopAppBar(title = { Text("Settings") }) }) { pad ->
        Column(
            Modifier.padding(pad).fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            val g = app.game
            if (g != null && !g.finished) {
                Text("Changes apply from the next new game. The game in progress keeps the settings it started with.",
                    color = Palette.Secondary, fontSize = 13.sp)
            }
            SettingsFields(app.settings) { app.engine.settings = it.sanitized() }
            Card(Modifier.fillMaxWidth()) {
                Label("RESULTS")
                Text("Every finished game is saved as a text document named home-away-location-date & time. " +
                    "Use Share results on the final screen or in History to send it, or Save a copy to put it in your files.",
                    color = Palette.Secondary, fontSize = 13.sp, modifier = Modifier.padding(top = 6.dp))
            }
            Card(Modifier.fillMaxWidth().clickable { about = true }) {
                Text("About Indoor Softball", fontWeight = FontWeight.SemiBold)
                Text("Version ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE}) · Developed by Steve Karmeinsky · © 2026 NetTek Ltd",
                    color = Palette.Secondary, fontSize = 12.sp)
            }
            TextButton(onClick = {
                // Indoor scoring, 2 innings, 5:00 halves, HR +5, OC −2; keeps the team names and location.
                app.engine.settings = GameSettings(
                    awayName = app.settings.awayName, homeName = app.settings.homeName, location = app.settings.location,
                )
            }) { Text("Reset everything to indoor defaults", color = Palette.Negative) }
        }
    }
}

@Composable
private fun AboutScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    BackHandler(onBack = onBack)
    fun open(url: String) {
        runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }
    }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("About") },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back") } },
            )
        },
    ) { pad ->
        Column(
            Modifier.padding(pad).fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(Modifier.widthIn(max = 640.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Image(painterResource(R.drawable.about_icon), null, Modifier.size(112.dp).clip(RoundedCornerShape(25.dp)))
                Text("Indoor Softball", fontSize = 28.sp, fontWeight = FontWeight.Black)
                Text("Version ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})", color = Palette.Secondary)
                Text("Score keeper and half-inning timer for indoor softball, on phone, tablet and watch.",
                    color = Palette.Secondary, textAlign = TextAlign.Center)
                Card(Modifier.fillMaxWidth()) {
                    Label("DEVELOPED BY", Palette.Powder)
                    Text("Steve Karmeinsky", fontSize = 20.sp, fontWeight = FontWeight.Bold)
                    Text("© 2026 NetTek Ltd", color = Palette.Secondary)
                }
                Card(Modifier.fillMaxWidth()) {
                    Label("ABOUT NETTEK", Palette.Powder)
                    Text("NetTek Ltd is a London-based internet and telecommunications consultancy, founded in 1994.")
                    Text("Its work spans mobile and watch app development, electronics design, web development and server administration.",
                        color = Palette.Secondary, fontSize = 14.sp, modifier = Modifier.padding(top = 6.dp))
                }
                Card(Modifier.fillMaxWidth()) {
                    for ((label, url) in listOf(
                        "nettek.uk" to "https://nettek.uk",
                        "Help & support" to "https://nettek.uk/indoor-softball/",
                        "Privacy policy" to "https://nettek.uk/indoor-softball/privacy/",
                        "Email feedback" to "mailto:support@nettek.uk?subject=" + Uri.encode("Indoor Softball (Android) ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})"),
                    )) {
                        Text(label, Modifier.fillMaxWidth().clickable { open(url) }.padding(vertical = 10.dp),
                            color = Palette.Positive, fontWeight = FontWeight.Medium)
                    }
                }
                Text("© 2026 NetTek Ltd. All rights reserved.", color = Palette.Secondary, fontSize = 12.sp)
            }
        }
    }
}
