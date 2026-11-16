package uk.nettek.indoorsoftball

import android.app.Application
import android.content.res.Configuration
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import uk.nettek.indoorsoftball.shared.FileGameStorage
import uk.nettek.indoorsoftball.shared.Game
import uk.nettek.indoorsoftball.shared.GameEngine
import uk.nettek.indoorsoftball.shared.GameFeedback
import uk.nettek.indoorsoftball.shared.GameSettings
import java.io.File

class IndoorSoftballApp : Application() {
    lateinit var state: AppState
        private set

    override fun onCreate() {
        super.onCreate()
        state = AppState(this)
    }
}

/**
 * Owns the game engine and mirrors it into Compose state. Also supplies the
 * platform side of the engine: haptics, sounds, alerts and results files.
 */
class AppState(private val app: Application) : GameFeedback {
    private val isTablet =
        app.resources.configuration.screenLayout and Configuration.SCREENLAYOUT_SIZE_MASK >= Configuration.SCREENLAYOUT_SIZE_LARGE

    val archive = ResultsArchive(app, File(app.filesDir, "results"))
    val engine = GameEngine(FileGameStorage(File(app.filesDir, "data")), if (isTablet) "Tablet" else "Phone", this)

    var game: Game? by mutableStateOf(engine.game)
        private set
    var settings: GameSettings by mutableStateOf(engine.settings)
        private set
    var history: List<Game> by mutableStateOf(engine.history)
        private set

    /** Updated a few times a second so the clock redraws. */
    var now: Long by mutableLongStateOf(System.currentTimeMillis())
        private set

    /** True while a game is in progress: the screen is kept on. */
    var keepAwake: Boolean by mutableStateOf(engine.game?.finished == false)
        private set

    /** Set by the activity; alerts are only posted as notifications in the background. */
    var inForeground = false

    private val vibrator: Vibrator? = app.getSystemService(Vibrator::class.java)
    private val tone: ToneGenerator? = runCatching { ToneGenerator(AudioManager.STREAM_NOTIFICATION, 100) }.getOrNull()
    private val scope = MainScope()

    init {
        engine.onChange = {
            game = engine.game
            settings = engine.settings
            history = engine.history
        }
        // Save every finished game (including ones from the watch) as a text document.
        engine.onGameArchived = { archive.save(it) }
        engine.onGameRenamed = { old, new ->
            archive.delete(old)
            archive.save(new)
        }
        engine.onGamesDeleted = { games, deleteFiles -> if (deleteFiles) games.forEach(archive::delete) }
        WearSync.attach(app, engine)
        Alerts.createChannel(app)
        scope.launch {
            while (true) {
                engine.tick()
                now = System.currentTimeMillis()
                delay(250)
            }
        }
    }

    // ---- GameFeedback

    private fun buzz(vararg pattern: Long) {
        runCatching { vibrator?.vibrate(VibrationEffect.createWaveform(pattern, -1)) }
    }

    override fun scored(points: Int) {
        if (points >= 0) buzz(0, 30) else buzz(0, 40, 60, 40)
    }

    override fun warning() {
        buzz(0, 150, 100, 150)
        runCatching { tone?.startTone(ToneGenerator.TONE_PROP_BEEP, 200) }
    }

    override fun timeUp() {
        // Three strong bursts plus a tone – hard to miss in a noisy hall.
        buzz(0, 400, 200, 400, 200, 400)
        runCatching { tone?.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, 1200) }
    }

    override fun halfClosed() = buzz(0, 60)

    override fun scheduleAlerts(timeUpAt: Long?, warningAt: Long?, halfLabel: String) =
        Alerts.schedule(app, timeUpAt, warningAt, halfLabel)

    override fun gameActiveChanged(active: Boolean) {
        keepAwake = active
    }
}
