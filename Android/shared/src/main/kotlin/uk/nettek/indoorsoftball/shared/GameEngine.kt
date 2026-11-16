package uk.nettek.indoorsoftball.shared

import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import java.io.File
import java.util.UUID

// The single source of truth for both Android apps: settings, the game in
// progress and finished games. Port of iOS Shared/Engine/GameStore.swift –
// all scoring and timing rules live here so phone and watch behave identically.

/** What the clock is doing, for colouring the UI. */
enum class ClockStatus { READY, RUNNING, PAUSED, WARNING, TIME_UP, CLOSED }

/** Platform hooks: haptics, notifications, screen-awake. */
interface GameFeedback {
    fun scored(points: Int) {}
    fun warning() {}
    fun timeUp() {}
    fun halfClosed() {}

    /** Schedule background alerts for the running clock (null = nothing running). */
    fun scheduleAlerts(timeUpAt: Long?, warningAt: Long?, halfLabel: String) {}
    fun gameActiveChanged(active: Boolean) {}
}

interface GameStorage {
    fun loadSettings(): GameSettings?
    fun saveSettings(settings: GameSettings)
    fun loadCurrentGame(): Game?
    fun saveCurrentGame(game: Game?)
    fun loadHistory(): List<Game>
    fun saveHistory(history: List<Game>)
}

val GameJson = Json {
    ignoreUnknownKeys = true
    encodeDefaults = true
}

/** Small JSON files in the app's private storage. */
class FileGameStorage(private val dir: File) : GameStorage {
    private fun file(name: String) = File(dir, name)

    private inline fun <T> read(name: String, decode: (String) -> T): T? =
        runCatching { decode(file(name).readText()) }.getOrNull()

    private fun write(name: String, text: String?) {
        runCatching {
            dir.mkdirs()
            if (text == null) file(name).delete() else file(name).writeText(text)
        }
    }

    override fun loadSettings() = read("settings.json") { GameJson.decodeFromString(GameSettings.serializer(), it) }
    override fun saveSettings(settings: GameSettings) =
        write("settings.json", GameJson.encodeToString(GameSettings.serializer(), settings))

    override fun loadCurrentGame() = read("current-game.json") { GameJson.decodeFromString(Game.serializer(), it) }
    override fun saveCurrentGame(game: Game?) =
        write("current-game.json", game?.let { GameJson.encodeToString(Game.serializer(), it) })

    override fun loadHistory() =
        read("history.json") { GameJson.decodeFromString(ListSerializer(Game.serializer()), it) } ?: emptyList()

    override fun saveHistory(history: List<Game>) =
        write("history.json", GameJson.encodeToString(ListSerializer(Game.serializer()), history))
}

/** Keeps everything in memory – used in tests. */
class MemoryGameStorage : GameStorage {
    var settings: GameSettings? = null
    var current: Game? = null
    var history: List<Game> = emptyList()
    override fun loadSettings() = settings
    override fun saveSettings(settings: GameSettings) { this.settings = settings }
    override fun loadCurrentGame() = current
    override fun saveCurrentGame(game: Game?) { current = game }
    override fun loadHistory() = history
    override fun saveHistory(history: List<Game>) { this.history = history }
}

class GameEngine(
    private val storage: GameStorage,
    val deviceName: String,
    var feedback: GameFeedback? = null,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    /** Settings for the next game. Saved on change and carried forward until changed. */
    var settings: GameSettings = (storage.loadSettings() ?: GameSettings()).sanitized()
        set(value) {
            if (value == field) return
            field = value
            storage.saveSettings(value)
            if (!applyingRemote) onSettingsChanged?.invoke(value)
            onChange?.invoke()
        }

    /** The game being scored (or just finished and still on screen). */
    var game: Game? = storage.loadCurrentGame()
        private set(value) {
            field = value
            storage.saveCurrentGame(value)
            onChange?.invoke()
        }

    /** Finished games, newest first. */
    var history: List<Game> = storage.loadHistory()
        private set(value) {
            field = value
            storage.saveHistory(value)
            onChange?.invoke()
        }

    /** Called after any change, so the UI can refresh. */
    var onChange: (() -> Unit)? = null

    /** Called when settings change locally (to sync to the paired device). */
    var onSettingsChanged: ((GameSettings) -> Unit)? = null

    /** Called when a game is finished on this device (to send it to the paired device). */
    var onGameFinished: ((Game) -> Unit)? = null

    /** Called whenever a finished game is added to History, locally or from the watch. */
    var onGameArchived: ((Game) -> Unit)? = null

    /** Called when a finished game's teams or location change (old, new). */
    var onGameRenamed: ((Game, Game) -> Unit)? = null

    /** Called when games are removed from History; Boolean = also delete their files. */
    var onGamesDeleted: ((List<Game>, Boolean) -> Unit)? = null

    private var warnedHalf: Int? = null
    private var timeUpHalf: Int? = null
    private var applyingRemote = false

    init {
        // Don't replay alerts that already fired before the app was closed.
        game?.let { g ->
            if (!g.finished) {
                val rem = g.current.timer.remaining(clock())
                if (rem <= g.settings.warningSeconds * 1000L) warnedHalf = g.currentIndex
                if (rem <= 0) timeUpHalf = g.currentIndex
            }
        }
    }

    private fun Game.withCurrent(change: (HalfInning) -> HalfInning): Game =
        copy(halves = halves.mapIndexed { i, h -> if (i == currentIndex) change(h) else h })

    // ---- Clock

    /** Advances the clock and fires warning / time-up alerts once each per half. */
    fun tick(now: Long = clock()) {
        val g = game ?: return
        if (g.finished) return
        val half = g.current
        if (!half.timer.hasStarted) return
        val remaining = half.timer.remaining(now)
        val warnAt = g.settings.warningSeconds * 1000L
        if (warnAt > 0 && remaining <= warnAt && remaining > 0 && warnedHalf != g.currentIndex) {
            warnedHalf = g.currentIndex
            feedback?.warning()
        }
        if (remaining <= 0) {
            // Time is up: the clock stops at exactly 0:00 and the half is over.
            // Scores can still be entered until the next half is started.
            half.timer.endAt?.let { end -> game = g.withCurrent { it.copy(timer = it.timer.pause(end)) } }
            if (timeUpHalf != g.currentIndex) {
                timeUpHalf = g.currentIndex
                warnedHalf = g.currentIndex
                feedback?.timeUp()
            }
        }
    }

    fun clockStatus(now: Long = clock()): ClockStatus {
        val g = game ?: return ClockStatus.READY
        if (g.finished) return ClockStatus.CLOSED
        val t = g.current.timer
        return when {
            t.hasStarted && t.remaining(now) <= 0 -> ClockStatus.TIME_UP
            !t.hasStarted -> ClockStatus.READY
            !t.isRunning -> ClockStatus.PAUSED
            t.remaining(now) <= g.settings.warningSeconds * 1000L -> ClockStatus.WARNING
            else -> ClockStatus.RUNNING
        }
    }

    fun remaining(now: Long = clock()): Long =
        game?.current?.timer?.remaining(now) ?: (settings.halfInningSeconds * 1000L)

    // ---- Game lifecycle

    /**
     * Starts a new game with the current settings. `rememberNames = false`
     * (the watch) uses the names for this game only.
     */
    fun newGame(
        awayName: String? = null, homeName: String? = null, location: String? = null,
        rememberNames: Boolean = true, now: Long = clock(),
    ) {
        var s = settings
        if (rememberNames) {
            s = s.copy(
                awayName = awayName ?: s.awayName,
                homeName = homeName ?: s.homeName,
                location = location ?: s.location,
            )
        }
        settings = s.sanitized()
        game = Game.create(
            id = UUID.randomUUID().toString(),
            settings = settings,
            awayName = awayName ?: settings.awayName,
            homeName = homeName ?: settings.homeName,
            location = if (rememberNames) (location ?: settings.location) else location,
            at = now,
            scoredOn = deviceName,
        )
        warnedHalf = null
        timeUpHalf = null
        feedback?.scheduleAlerts(null, null, "")
        feedback?.gameActiveChanged(true)
    }

    /** Throws away the game in progress without saving it. */
    fun discardGame() {
        game = null
        feedback?.scheduleAlerts(null, null, "")
        feedback?.gameActiveChanged(false)
    }

    /** Clears a finished game from the main screen (it stays in history). */
    fun closeFinishedGame() {
        if (game?.finished == true) game = null
    }

    // ---- Timer control

    fun startClock(now: Long = clock()) {
        val g = game ?: return
        if (g.finished) return
        game = g.copy(playStartedAt = g.playStartedAt ?: now).withCurrent { it.copy(timer = it.timer.start(now)) }
        rescheduleAlerts(now)
    }

    fun pauseClock(now: Long = clock()) {
        val g = game ?: return
        if (g.finished) return
        game = g.withCurrent { it.copy(timer = it.timer.pause(now)) }
        rescheduleAlerts(now)
    }

    fun toggleClock(now: Long = clock()) {
        val g = game ?: return
        if (g.current.timer.isRunning) pauseClock(now) else startClock(now)
    }

    /** Adds (positive) or takes off (negative) time from the current half's clock. */
    fun addTime(seconds: Int, now: Long = clock()) {
        val g = game ?: return
        if (g.finished) return
        val updated = g.withCurrent { it.copy(timer = it.timer.addTime(seconds * 1000L, now)) }
        game = updated
        val rem = updated.current.timer.remaining(now)
        // Allow alerts to fire again if time was added back.
        if (rem > 0 && timeUpHalf == g.currentIndex) timeUpHalf = null
        if (rem > g.settings.warningSeconds * 1000L && warnedHalf == g.currentIndex) warnedHalf = null
        rescheduleAlerts(now)
    }

    private fun rescheduleAlerts(now: Long) {
        val g = game
        val end = g?.current?.timer?.endAt
        if (g == null || g.finished || end == null || end <= now) {
            feedback?.scheduleAlerts(null, null, "")
            return
        }
        val warn = if (g.settings.warningSeconds > 0) end - g.settings.warningSeconds * 1000L else null
        feedback?.scheduleAlerts(end, warn?.takeIf { it > now }, g.current.label)
    }

    // ---- Scoring

    /**
     * Records a scoring tap in the open half. Allowed after time is up, right
     * up until the next half is started.
     */
    fun record(kind: EventKind, runnersOn: Int = 0, now: Long = clock()): ScoreEvent? {
        val g = game ?: return null
        if (g.finished) return null
        val event = ScoringRules.makeEvent(kind, runnersOn, g.settings, now)
        game = g.withCurrent { it.copy(events = it.events + event) }
        feedback?.scored(event.points)
        return event
    }

    val canUndo: Boolean get() = game?.let { !it.finished && it.current.events.isNotEmpty() } ?: false

    /** Removes the most recent entry in the open half. */
    fun undo() {
        val g = game ?: return
        if (g.finished || g.current.events.isEmpty()) return
        game = g.withCurrent { it.copy(events = it.events.dropLast(1)) }
    }

    // ---- Moving between halves

    /** Closes the open half and opens the next one. On the last half use finishGame(). */
    fun startNextHalf(now: Long = clock()) {
        val g = game ?: return
        if (g.finished || g.isLastHalf) return
        game = g.withCurrent { it.copy(timer = it.timer.pause(now), closedAt = now) }
            .copy(currentIndex = g.currentIndex + 1)
        warnedHalf = null
        timeUpHalf = null
        feedback?.halfClosed()
        rescheduleAlerts(now)
    }

    /** Used by the clock's "Start Bottom 1" button: locks the half and starts the next clock. */
    fun startNextHalfAndClock(now: Long = clock()) {
        val g = game ?: return
        if (g.finished || g.isLastHalf) return
        startNextHalf(now)
        startClock(now)
    }

    /** Ends the game (normally after the last half; can also end early). */
    fun finishGame(now: Long = clock()) {
        val g = game ?: return
        if (g.finished) return
        val done = g.withCurrent { it.copy(timer = it.timer.pause(now), closedAt = now) }
            .copy(finished = true, endedAt = now)
        game = done
        upsertHistory(done)
        feedback?.halfClosed()
        feedback?.scheduleAlerts(null, null, "")
        feedback?.gameActiveChanged(false)
        onGameFinished?.invoke(done)
    }

    // ---- History

    private fun upsertHistory(g: Game) {
        history = (history.filter { it.id != g.id } + g).sortedByDescending { it.playStart }
        onGameArchived?.invoke(g)
    }

    /** Removes games from History; `deleteFiles` also removes their results files. */
    fun deleteHistory(ids: Set<String>, deleteFiles: Boolean = false) {
        val removed = history.filter { it.id in ids }
        history = history.filter { it.id !in ids }
        onGamesDeleted?.invoke(removed, deleteFiles)
    }

    /**
     * Changes the team names and location of a finished game (e.g. one scored
     * on the watch as Away v Home). Its results file is renamed to match.
     */
    fun updateDetails(gameId: String, away: String, home: String, location: String) {
        val old = history.firstOrNull { it.id == gameId } ?: return
        val new = old.copy(
            awayName = away.trim().ifEmpty { "Away" },
            homeName = home.trim().ifEmpty { "Home" },
            location = location.trim().takeIf { it.isNotEmpty() },
        )
        if (new == old) return
        history = history.map { if (it.id == gameId) new else it }
        if (game?.id == gameId) game = new
        onGameRenamed?.invoke(old, new)
    }

    // ---- Sync from the paired device

    fun receiveRemoteSettings(s: GameSettings) {
        applyingRemote = true
        settings = s.sanitized()
        applyingRemote = false
    }

    fun receiveRemoteGame(g: Game) {
        if (g.finished) upsertHistory(g)
    }
}
