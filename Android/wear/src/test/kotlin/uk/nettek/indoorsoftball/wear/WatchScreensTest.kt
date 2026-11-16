package uk.nettek.indoorsoftball.wear

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeUp
import com.github.takahirom.roborazzi.captureRoboImage
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import uk.nettek.indoorsoftball.shared.EventKind
import uk.nettek.indoorsoftball.shared.ScoringType

/**
 * Draws the watch app's real screens to PNG files in wear/build/screens, so
 * layouts can be checked without a watch. Run: ./gradlew :wear:testDebugUnitTest
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
abstract class WatchScreensBase(private val tag: String) {
    @get:Rule
    val rule = createAndroidComposeRule<MainActivity>()

    private fun settle() {
        rule.runOnUiThread { androidx.compose.runtime.snapshots.Snapshot.sendApplyNotifications() }
        org.robolectric.shadows.ShadowLooper.idleMainLooper()
        rule.mainClock.advanceTimeBy(1500)
        rule.waitForIdle()
    }

    private fun shot(name: String) {
        settle()
        rule.onRoot().captureRoboImage("build/screens/${tag}_$name.png")
    }

    private fun nextPage() {
        settle()
        rule.onRoot().performTouchInput { swipeUp(durationMillis = 200) }
    }

    @Test
    fun screens() {
        rule.mainClock.autoAdvance = false
        val engine = (rule.activity.application as WearApp).state.engine
        fun ui(block: () -> Unit) = rule.runOnUiThread(block)

        shot("1_start")

        ui {
            engine.settings = engine.settings.copy(scoring = ScoringType.INDOOR)
            engine.newGame("Away", "Home", rememberNames = false)
            repeat(11) { engine.record(EventKind.PLUS) }; repeat(2) { engine.record(EventKind.MINUS) }
            engine.startNextHalf()
            repeat(8) { engine.record(EventKind.PLUS) }; repeat(2) { engine.record(EventKind.MINUS) }
            engine.startNextHalf()
            engine.record(EventKind.HOME_RUN); repeat(2) { engine.record(EventKind.PLUS) }; engine.record(EventKind.OUT_BY_CATCHER)
            engine.startClock(System.currentTimeMillis() - 133_000)
        }
        shot("2_clock")
        nextPage(); shot("3_score_indoor")
        nextPage(); shot("4_tally")
        nextPage(); shot("5_controls")

        ui { engine.tick(System.currentTimeMillis() + 400_000) }
        shot("6_controls_time_up")

        ui {
            engine.startNextHalf()
            engine.record(EventKind.HOME_RUN); repeat(7) { engine.record(EventKind.PLUS) }
            engine.finishGame()
        }
        shot("7_final")

        ui {
            engine.settings = engine.settings.copy(scoring = ScoringType.OUTDOOR)
            engine.newGame("Away", "Home", rememberNames = false)
            engine.record(EventKind.PLUS); engine.record(EventKind.HOME_RUN, runnersOn = 2)
            engine.startClock(System.currentTimeMillis() - 60_000)
        }
        shot("8_clock_outdoor")
        nextPage(); shot("9_score_outdoor")
    }
}

// Robolectric keeps 56dp of the height for system bars, so each height is the
// watch size plus 56: the drawn area comes out square, as on a real watch.
@Config(sdk = [34], qualifiers = "w192dp-h248dp-round-xhdpi")
class SmallRoundWatch : WatchScreensBase("round192")

@Config(sdk = [34], qualifiers = "w225dp-h281dp-round-xhdpi")
class LargeRoundWatch : WatchScreensBase("round225")

@Config(sdk = [34], qualifiers = "w180dp-h236dp-notround-xhdpi")
class SquareWatch : WatchScreensBase("square180")
