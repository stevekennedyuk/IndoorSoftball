package uk.nettek.indoorsoftball

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onRoot
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
 * Draws the app's real screens to PNG files in app/build/screens, so layouts
 * can be checked without a device. Run: ./gradlew :app:testDebugUnitTest
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
abstract class ScreensBase(private val tag: String) {
    @get:Rule
    val rule = createAndroidComposeRule<MainActivity>()

    private fun shot(name: String) {
        // Let the state changes reach the screen before capturing it.
        rule.runOnUiThread { androidx.compose.runtime.snapshots.Snapshot.sendApplyNotifications() }
        org.robolectric.shadows.ShadowLooper.idleMainLooper()
        rule.mainClock.advanceTimeBy(600)
        rule.waitForIdle()
        rule.onRoot().captureRoboImage("build/screens/${tag}_$name.png")
    }

    @Test
    fun screens() {
        rule.mainClock.autoAdvance = false
        val engine = (rule.activity.application as IndoorSoftballApp).state.engine
        fun ui(block: () -> Unit) = rule.runOnUiThread(block)

        shot("1_start")

        ui {
            engine.newGame("Hawks", "Owls", "Hackney Leisure Centre")
            repeat(11) { engine.record(EventKind.PLUS) }; repeat(2) { engine.record(EventKind.MINUS) }
            engine.startNextHalf()
            repeat(8) { engine.record(EventKind.PLUS) }; repeat(2) { engine.record(EventKind.MINUS) }
            engine.startNextHalf()
            engine.record(EventKind.HOME_RUN); repeat(2) { engine.record(EventKind.PLUS) }; engine.record(EventKind.OUT_BY_CATCHER)
            engine.startClock(System.currentTimeMillis() - 133_000)
        }
        shot("2_indoor_live")

        ui { engine.tick(System.currentTimeMillis() + 400_000) }
        shot("3_time_up")

        ui {
            engine.startNextHalf()
            engine.record(EventKind.HOME_RUN); repeat(7) { engine.record(EventKind.PLUS) }; engine.record(EventKind.MINUS)
            engine.finishGame()
        }
        shot("4_final")

        ui {
            engine.settings = engine.settings.copy(scoring = ScoringType.OUTDOOR)
            engine.newGame("Hawks", "Owls", "Victoria Park")
            engine.record(EventKind.PLUS); engine.record(EventKind.HOME_RUN, runnersOn = 2)
            engine.startClock(System.currentTimeMillis() - 60_000)
        }
        shot("5_outdoor_live")
    }
}

@Config(sdk = [34], qualifiers = "w411dp-h891dp-xxhdpi")
class PhoneScreens : ScreensBase("phone")

@Config(sdk = [34], qualifiers = "w360dp-h640dp-xhdpi")
class SmallPhoneScreens : ScreensBase("small")

@Config(sdk = [34], qualifiers = "w1280dp-h800dp-land-hdpi")
class TabletScreens : ScreensBase("tablet")
