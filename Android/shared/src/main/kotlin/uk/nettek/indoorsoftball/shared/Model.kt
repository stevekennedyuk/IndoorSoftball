package uk.nettek.indoorsoftball.shared

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// The data model and scoring rules. This is a port of the iOS app's
// Shared/Model (GameSettings, ScoreEvent, Game); keep the two in step.
// All times are epoch milliseconds.

/** Which set of scoring buttons a game uses. */
@Serializable
enum class ScoringType {
    /** +1, −1, HR (home run off the wall) and OC (out by the catcher at home). */
    @SerialName("indoor") INDOOR,

    /** Runs only: +1, and HR+1 / HR+2 / HR+3 (home run with 1–3 runners on = 2–4 runs). */
    @SerialName("outdoor") OUTDOOR;

    val title: String get() = if (this == INDOOR) "Indoor" else "Outdoor"
}

/**
 * Rule and timing settings. Remembered between games; each game takes a
 * snapshot when it starts, so changing a setting never alters a game in progress.
 */
@Serializable
data class GameSettings(
    val scoring: ScoringType = ScoringType.INDOOR,
    /** Full innings (Away bats + Home bats = 1 inning). */
    val innings: Int = 2,
    /** Length of each half inning, in seconds (30-second steps). */
    val halfInningSeconds: Int = 300,
    /** Indoor: points for a home run off the back wall. */
    val homeRunPoints: Int = 5,
    /** Indoor: points for an out by the catcher at home (normally negative). */
    val outAtHomeByCatcherPoints: Int = -2,
    /** Seconds remaining at which the "nearly time" warning fires (0 = off). */
    val warningSeconds: Int = 60,
    /** Last-used team names and location, offered again for the next game. */
    val awayName: String = "Away",
    val homeName: String = "Home",
    val location: String = "",
) {
    val halvesCount: Int get() = innings * 2

    /** Clamps every value into its allowed range. */
    fun sanitized(): GameSettings = copy(
        innings = innings.coerceIn(INNINGS_RANGE),
        halfInningSeconds = ((halfInningSeconds + HALF_STEP / 2) / HALF_STEP * HALF_STEP).coerceIn(HALF_RANGE),
        homeRunPoints = homeRunPoints.coerceIn(HOME_RUN_RANGE),
        outAtHomeByCatcherPoints = outAtHomeByCatcherPoints.coerceIn(OUT_RANGE),
        warningSeconds = warningSeconds.coerceIn(WARNING_RANGE),
        location = location.trim(),
    )

    companion object {
        val INNINGS_RANGE = 1..9
        val HALF_RANGE = 30..1800
        const val HALF_STEP = 30
        val HOME_RUN_RANGE = 0..20
        val OUT_RANGE = -5..0
        val WARNING_RANGE = 0..300
        const val WARNING_STEP = 15
    }
}

/** The scoring buttons. */
@Serializable
enum class EventKind {
    @SerialName("plus") PLUS,                    // +1
    @SerialName("minus") MINUS,                  // −1 (indoor)
    @SerialName("homeRun") HOME_RUN,             // HR (indoor) or HR+n (outdoor)
    @SerialName("outByCatcher") OUT_BY_CATCHER,  // OC (indoor)
}

/** One scoring entry. The points are fixed when the entry is made. */
@Serializable
data class ScoreEvent(
    val kind: EventKind,
    val points: Int,
    /** Outdoor home run: runners on base (1–3). */
    val runnersOn: Int = 0,
    val at: Long = 0,
)

object ScoringRules {
    fun points(kind: EventKind, runnersOn: Int = 0, s: GameSettings): Int = when (kind) {
        EventKind.PLUS -> 1
        EventKind.MINUS -> -1
        EventKind.HOME_RUN -> {
            val runners = runnersOn.coerceIn(0, 3)
            // Outdoor: the batter's run plus one per runner on (HR+1 = 2 … HR+3 = 4).
            if (s.scoring == ScoringType.OUTDOOR) 1 + runners else s.homeRunPoints
        }
        EventKind.OUT_BY_CATCHER -> s.outAtHomeByCatcherPoints
    }

    fun makeEvent(kind: EventKind, runnersOn: Int, s: GameSettings, at: Long): ScoreEvent {
        val runners = if (kind == EventKind.HOME_RUN) runnersOn.coerceIn(0, 3) else 0
        return ScoreEvent(kind, points(kind, runners, s), runners, at)
    }
}

enum class Team { AWAY, HOME }

/**
 * A countdown clock for one half inning, stored as wall-clock values so it
 * stays correct while the app is in the background.
 */
@Serializable
data class HalfTimer(
    val durationMs: Long,
    /** Time run before the current running stretch. */
    val accumulatedMs: Long = 0,
    /** When the current running stretch began (null = paused / not started). */
    val runningSince: Long? = null,
) {
    val isRunning: Boolean get() = runningSince != null
    val hasStarted: Boolean get() = isRunning || accumulatedMs > 0

    fun elapsed(now: Long): Long = accumulatedMs + (runningSince?.let { maxOf(0, now - it) } ?: 0)

    /** Milliseconds left (the engine stops the clock at zero). */
    fun remaining(now: Long): Long = durationMs - elapsed(now)

    /** When the clock will hit zero, if running. */
    val endAt: Long? get() = runningSince?.let { it + durationMs - accumulatedMs }

    /** 0…1 fraction used. */
    fun progress(now: Long): Float =
        if (durationMs <= 0) 1f else (elapsed(now).toFloat() / durationMs).coerceIn(0f, 1f)

    fun start(now: Long): HalfTimer = if (runningSince != null) this else copy(runningSince = now)

    fun pause(now: Long): HalfTimer {
        val since = runningSince ?: return this
        return copy(accumulatedMs = accumulatedMs + maxOf(0, now - since), runningSince = null)
    }

    /** Adds (or with a negative value removes) time; never below zero used. */
    fun addTime(ms: Long, now: Long): HalfTimer {
        val used = maxOf(0, elapsed(now) - ms)
        return if (runningSince != null) copy(accumulatedMs = used, runningSince = now) else copy(accumulatedMs = used)
    }
}

@Serializable
data class HalfInning(
    /** 0-based: 0 = Top 1, 1 = Bottom 1, 2 = Top 2… */
    val index: Int,
    val events: List<ScoreEvent> = emptyList(),
    val timer: HalfTimer,
    val closedAt: Long? = null,
) {
    val inning: Int get() = index / 2 + 1
    val isTop: Boolean get() = index % 2 == 0
    val battingTeam: Team get() = if (isTop) Team.AWAY else Team.HOME
    val positive: Int get() = events.filter { it.points > 0 }.sumOf { it.points }
    val negative: Int get() = events.filter { it.points < 0 }.sumOf { it.points }
    val net: Int get() = events.sumOf { it.points }
    val label: String get() = "${if (isTop) "Top" else "Bottom"} $inning"
    val shortLabel: String get() = "${if (isTop) "▲" else "▼"}$inning"
}

/** A whole game. Away bats in the top (even-indexed) halves. */
@Serializable
data class Game(
    val id: String,
    val settings: GameSettings,
    val awayName: String,
    val homeName: String,
    /** Where the game was played (optional). */
    val location: String? = null,
    val halves: List<HalfInning>,
    /** The half currently open for scoring. */
    val currentIndex: Int = 0,
    val finished: Boolean = false,
    /** When the game was set up (New Game tapped). */
    val startedAt: Long,
    /** When play actually started: the first time the clock was started. */
    val playStartedAt: Long? = null,
    val endedAt: Long? = null,
    /** "Phone", "Tablet" or "Watch" – where it was scored. */
    val scoredOn: String = "",
) {
    val current: HalfInning get() = halves[currentIndex]
    val isLastHalf: Boolean get() = currentIndex == halves.size - 1
    val inningsCount: Int get() = halves.size / 2
    val playStart: Long get() = playStartedAt ?: startedAt

    fun name(team: Team): String = if (team == Team.AWAY) awayName else homeName

    fun half(team: Team, inning: Int): HalfInning? =
        halves.getOrNull((inning - 1) * 2 + if (team == Team.AWAY) 0 else 1)

    /** Whether a half has been reached yet. */
    fun isReached(half: HalfInning): Boolean = half.index <= currentIndex

    private fun played(team: Team) = halves.filter { it.battingTeam == team && isReached(it) }

    fun total(team: Team): Int = played(team).sumOf { it.net }
    fun positiveTotal(team: Team): Int = played(team).sumOf { it.positive }
    fun negativeTotal(team: Team): Int = played(team).sumOf { it.negative }

    /** Team's running total at the end of the given inning (1-based). */
    fun cumulative(team: Team, throughInning: Int): Int =
        played(team).filter { it.inning <= throughInning }.sumOf { it.net }

    /** Highest score wins (so −5 beats −10). null = tie (ties stand). */
    val leader: Team?
        get() {
            val a = total(Team.AWAY)
            val h = total(Team.HOME)
            return if (a == h) null else if (a > h) Team.AWAY else Team.HOME
        }

    val winner: Team? get() = if (finished) leader else null

    val resultText: String
        get() {
            val a = total(Team.AWAY)
            val h = total(Team.HOME)
            return when (leader) {
                null -> "Tied ${a.score()} – ${h.score()}"
                Team.AWAY -> "$awayName win ${a.score()} – ${h.score()}"
                Team.HOME -> "$homeName win ${h.score()} – ${a.score()}"
            }
        }

    /** The location, or "Location" if none was entered. */
    val place: String get() = location?.takeIf { it.isNotEmpty() } ?: "Location"

    val isFromWatch: Boolean get() = scoredOn == "Watch"

    /** A Watch game still showing the default names or no location. */
    val needsDetails: Boolean
        get() = isFromWatch && ((awayName == "Away" && homeName == "Home") || location == null)

    companion object {
        fun create(
            id: String, settings: GameSettings, awayName: String, homeName: String,
            location: String?, at: Long, scoredOn: String,
        ): Game {
            val s = settings.sanitized()
            return Game(
                id = id,
                settings = s,
                awayName = awayName.trim().ifEmpty { "Away" },
                homeName = homeName.trim().ifEmpty { "Home" },
                location = location?.trim()?.takeIf { it.isNotEmpty() },
                halves = List(s.halvesCount) { HalfInning(it, timer = HalfTimer(s.halfInningSeconds * 1000L)) },
                startedAt = at,
                scoredOn = scoredOn,
            )
        }
    }
}

/** "+3", "−2", "0" – true minus sign, for on-screen text. */
fun Int.signed(): String = if (this > 0) "+$this" else if (this < 0) "−${-this}" else "0"

/** "12", "−5" – plain score with a true minus sign. */
fun Int.score(): String = if (this < 0) "−${-this}" else "$this"

/** "4:59" while counting down; "0:00" once time is up. */
fun clockText(remainingMs: Long): String {
    val s = ((maxOf(0, remainingMs) + 999) / 1000).toInt()
    return "%d:%02d".format(s / 60, s % 60)
}

/** "5:00", "4:30", "30s" for settings. */
fun durationText(seconds: Int): String =
    if (seconds < 60) "${seconds}s" else "%d:%02d".format(seconds / 60, seconds % 60)
