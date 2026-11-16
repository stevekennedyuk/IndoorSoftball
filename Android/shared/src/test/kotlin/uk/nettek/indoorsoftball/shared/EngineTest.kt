package uk.nettek.indoorsoftball.shared

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Clock, alerts, history and persistence behaviour (the iOS checks cover the same ground). */
class EngineTest {
    private class Log : GameFeedback {
        val events = mutableListOf<String>()
        override fun warning() { events += "warning" }
        override fun timeUp() { events += "timeUp" }
    }

    private val t0 = 1_000_000_000L
    private fun sec(s: Int) = t0 + s * 1000L

    @Test
    fun clockStopsAtZeroAndScoringStaysOpen() {
        val log = Log()
        val e = GameEngine(MemoryGameStorage(), "Test", log)
        e.newGame("Bats", "Gloves", now = t0)
        assertEquals(ClockStatus.READY, e.clockStatus(t0))
        e.startClock(t0)
        assertEquals(ClockStatus.RUNNING, e.clockStatus(sec(100)))
        assertEquals(ClockStatus.WARNING, e.clockStatus(sec(250)))
        e.tick(sec(250)); e.tick(sec(260))
        assertEquals(1, log.events.count { it == "warning" })
        e.tick(sec(301))
        assertEquals(ClockStatus.TIME_UP, e.clockStatus(sec(301)))
        assertFalse(e.game!!.current.timer.isRunning)
        assertEquals(0L, e.game!!.current.timer.remaining(sec(999)))
        e.tick(sec(400))
        assertEquals(1, log.events.count { it == "timeUp" })
        // still scoring after time is up
        e.record(EventKind.PLUS, now = sec(310))
        assertEquals(1, e.game!!.current.net)
        e.startNextHalfAndClock(sec(320))
        assertEquals(1, e.game!!.currentIndex)
        assertTrue(e.game!!.current.timer.isRunning)
        assertEquals(1, e.game!!.halves[0].net)
    }

    @Test
    fun pauseResumeAndAddTime() {
        val e = GameEngine(MemoryGameStorage(), "Test")
        e.newGame(now = t0)
        e.startClock(t0)
        e.pauseClock(sec(60))
        assertEquals(240_000L, e.remaining(sec(500)))
        e.addTime(30, sec(500))
        assertEquals(270_000L, e.remaining(sec(500)))
        assertEquals(ClockStatus.PAUSED, e.clockStatus(sec(500)))
    }

    @Test
    fun playStartIsTheFirstClockStart() {
        val e = GameEngine(MemoryGameStorage(), "Test")
        e.newGame(now = t0)
        assertNull(e.game!!.playStartedAt)
        e.startClock(sec(600))
        e.pauseClock(sec(660))
        e.startClock(sec(700))
        assertEquals(sec(600), e.game!!.playStartedAt)
    }

    @Test
    fun lowestNegativeLosesAndGameKeepsItsSettings() {
        val e = GameEngine(MemoryGameStorage(), "Test")
        e.newGame()
        repeat(10) { e.record(EventKind.MINUS) }
        e.startNextHalf()
        repeat(5) { e.record(EventKind.MINUS) }
        e.settings = e.settings.copy(scoring = ScoringType.OUTDOOR)
        assertEquals(ScoringType.INDOOR, e.game!!.settings.scoring)
        e.startNextHalf(); e.startNextHalf()
        assertTrue(e.game!!.isLastHalf)
        e.startNextHalf() // no-op on the last half
        assertEquals(3, e.game!!.currentIndex)
        e.finishGame()
        assertEquals(Team.HOME, e.game!!.winner) // −5 beats −10
        assertNull(e.record(EventKind.PLUS))      // locked once finished
    }

    @Test
    fun watchGamesRenameAndDelete() {
        val watch = GameEngine(MemoryGameStorage(), "Watch")
        var sent: Game? = null
        watch.onGameFinished = { sent = it }
        watch.settings = watch.settings.copy(awayName = "Hawks", location = "Hall")
        watch.newGame("Away", "Home", rememberNames = false)
        assertEquals("Hawks", watch.settings.awayName)
        assertNull(watch.game!!.location)
        watch.record(EventKind.PLUS)
        watch.finishGame()

        val phone = GameEngine(MemoryGameStorage(), "Phone")
        val archived = mutableListOf<String>()
        val renamed = mutableListOf<String>()
        val deleted = mutableListOf<Boolean>()
        phone.onGameArchived = { archived += it.exportFileName() }
        phone.onGameRenamed = { old, new -> renamed += "${old.awayName}>${new.awayName}" }
        phone.onGamesDeleted = { _, files -> deleted += files }
        phone.receiveRemoteGame(sent!!)
        assertEquals(1, phone.history.size)
        assertTrue(phone.history[0].needsDetails)
        assertTrue(archived[0].startsWith("Home-Away-Location-"))
        phone.updateDetails(sent!!.id, "Hawks", "Owls", "Sobell")
        assertFalse(phone.history[0].needsDetails)
        assertEquals(listOf("Away>Hawks"), renamed)
        phone.deleteHistory(setOf(sent!!.id), deleteFiles = true)
        assertTrue(phone.history.isEmpty())
        assertEquals(listOf(true), deleted)
    }

    @Test
    fun settingsAndGamesSurviveARestartAndOldFilesStillLoad() {
        val storage = MemoryGameStorage()
        val e = GameEngine(storage, "Test")
        e.settings = e.settings.copy(scoring = ScoringType.OUTDOOR, innings = 3)
        e.newGame("A", "B", "C")
        e.record(EventKind.HOME_RUN, runnersOn = 2)
        val again = GameEngine(storage, "Test")
        assertEquals(e.game, again.game)
        assertEquals(3, again.settings.innings)
        assertEquals("C", again.settings.location)
        // JSON round trip, and settings saved before a field existed
        val json = GameJson.encodeToString(Game.serializer(), e.game!!)
        assertEquals(e.game, GameJson.decodeFromString(Game.serializer(), json))
        val old = GameJson.decodeFromString(GameSettings.serializer(), """{"innings":3,"futureField":1}""")
        assertEquals(ScoringType.INDOOR, old.scoring)
        assertEquals(95.let { GameSettings(halfInningSeconds = it).sanitized().halfInningSeconds }, 90)
    }

    @Test
    fun remoteSettingsDoNotEchoBack() {
        val e = GameEngine(MemoryGameStorage(), "Test")
        var sent = 0
        e.onSettingsChanged = { sent++ }
        e.receiveRemoteSettings(GameSettings(innings = 4))
        assertEquals(4, e.settings.innings)
        assertEquals(0, sent)
        e.settings = e.settings.copy(innings = 5)
        assertEquals(1, sent)
    }
}
