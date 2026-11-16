package uk.nettek.indoorsoftball.shared

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File
import java.time.LocalDateTime
import java.time.ZoneId

/** Runs SharedTests/cases.json – the cases the iOS engine must also pass. */
class ScoringCasesTest {
    private val cases = Json.parseToJsonElement(File(System.getProperty("sharedTests")).readText()).jsonObject

    private fun JsonObject.str(key: String) = getValue(key).jsonPrimitive.content
    private fun JsonObject.int(key: String) = getValue(key).jsonPrimitive.int
    private fun JsonObject.intOr(key: String, default: Int) = get(key)?.jsonPrimitive?.int ?: default

    private fun settings(c: JsonObject) = GameSettings(
        scoring = if (c.str("scoring") == "outdoor") ScoringType.OUTDOOR else ScoringType.INDOOR,
        innings = c.intOr("innings", 2),
        homeRunPoints = c.intOr("homeRunPoints", 5),
        outAtHomeByCatcherPoints = c.intOr("outAtHomeByCatcherPoints", -2),
    )

    private fun GameEngine.tap(tap: String) {
        val (what, times) = if ("x" in tap) tap.substringBefore("x") to tap.substringAfter("x").toInt() else tap to 1
        repeat(times) {
            when {
                what == "+1" -> record(EventKind.PLUS)
                what == "-1" -> record(EventKind.MINUS)
                what == "HR" -> record(EventKind.HOME_RUN)
                what == "OC" -> record(EventKind.OUT_BY_CATCHER)
                what.startsWith("HR+") -> record(EventKind.HOME_RUN, runnersOn = what.removePrefix("HR+").toInt())
                what == "undo" -> undo()
                else -> error("Unknown tap $tap")
            }
        }
    }

    @Test
    fun tallies() {
        for (c in cases.getValue("tallies").jsonArray.map { it.jsonObject }) {
            val engine = GameEngine(MemoryGameStorage(), "Test")
            engine.settings = settings(c)
            engine.newGame()
            c.getValue("taps").jsonArray.forEach { engine.tap(it.jsonPrimitive.content) }
            val half = engine.game!!.current
            val name = c.str("name")
            assertEquals("$name: plus", c.int("plus"), half.positive)
            assertEquals("$name: minus", c.int("minus"), half.negative)
            assertEquals("$name: total", c.int("total"), half.net)
        }
    }

    @Test
    fun games() {
        val zone = ZoneId.systemDefault()
        for (c in cases.getValue("games").jsonArray.map { it.jsonObject }) {
            val name = c.str("name")
            val play = LocalDateTime.parse(c.str("playStart")).atZone(zone).toInstant().toEpochMilli()
            val engine = GameEngine(MemoryGameStorage(), "Test")
            engine.settings = settings(c)
            // The game is set up ten minutes before play starts: the document must use the play-start time.
            engine.newGame(c.str("away"), c.str("home"), c.str("location"), now = play - 600_000)
            engine.startClock(play)
            val halves = c.getValue("halves").jsonArray
            halves.forEachIndexed { i, taps ->
                if (i > 0) engine.startNextHalf(play + i * 60_000L)
                taps.jsonArray.forEach { engine.tap(it.jsonPrimitive.content) }
            }
            engine.finishGame(play + 1_800_000)
            val g = engine.game!!
            assertEquals("$name: away total", c.int("awayTotal"), g.total(Team.AWAY))
            assertEquals("$name: home total", c.int("homeTotal"), g.total(Team.HOME))
            val winner = when (g.winner) { Team.AWAY -> "away"; Team.HOME -> "home"; null -> "tie" }
            assertEquals("$name: winner", c.str("winner"), winner)
            assertEquals("$name: file name", c.str("fileName"), g.exportFileName(zone))
            assertEquals("$name: subject", c.str("subject"), g.shareSubject(zone))
            assertEquals("$name: document", c.str("document"), g.resultsDocument(zone))
            assertEquals("$name: saved to history", g, engine.history.first())
        }
    }
}
