package uk.nettek.indoorsoftball.wear

import android.app.Application
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import uk.nettek.indoorsoftball.shared.FileGameStorage
import uk.nettek.indoorsoftball.shared.Game
import uk.nettek.indoorsoftball.shared.GameEngine
import uk.nettek.indoorsoftball.shared.GameFeedback
import uk.nettek.indoorsoftball.shared.GameJson
import uk.nettek.indoorsoftball.shared.GameSettings
import java.io.File

class WearApp : Application() {
    lateinit var state: WearState
        private set

    override fun onCreate() {
        super.onCreate()
        state = WearState(this)
    }
}

/** Owns the game engine on the watch and mirrors it into Compose state. */
class WearState(private val app: Application) : GameFeedback {
    val engine = GameEngine(FileGameStorage(File(app.filesDir, "data")), "Watch", this)

    var game: Game? by mutableStateOf(engine.game)
        private set
    var settings: GameSettings by mutableStateOf(engine.settings)
        private set

    /** Updated a few times a second so the clock redraws. */
    var now: Long by mutableLongStateOf(System.currentTimeMillis())
        private set

    private val vibrator: Vibrator? = app.getSystemService(Vibrator::class.java)
    private val scope = MainScope()

    init {
        engine.onChange = {
            game = engine.game
            settings = engine.settings
        }
        WearSync.attach(app, engine)
        scope.launch {
            while (true) {
                engine.tick()
                now = System.currentTimeMillis()
                delay(250)
            }
        }
    }

    private fun buzz(vararg pattern: Long) {
        runCatching { vibrator?.vibrate(VibrationEffect.createWaveform(pattern, -1)) }
    }

    override fun scored(points: Int) = if (points >= 0) buzz(0, 30) else buzz(0, 40, 60, 40)
    override fun warning() = buzz(0, 200, 120, 200)
    override fun timeUp() = buzz(0, 500, 200, 500, 200, 500, 200, 500)
    override fun halfClosed() = buzz(0, 80)
}

/**
 * Phone ↔ watch sync through the Wearable Data Layer. Settings are copied both
 * ways; each finished game is sent to the phone, which adds it to History and
 * saves its results file. Items wait in the Data Layer until the phone is reachable.
 */
object WearSync {
    const val SETTINGS_PATH = "/settings"
    const val GAME_PREFIX = "/game/"

    fun attach(context: Context, engine: GameEngine) {
        engine.onSettingsChanged = { settings ->
            put(context, SETTINGS_PATH, GameJson.encodeToString(GameSettings.serializer(), settings))
        }
        engine.onGameFinished = { game ->
            put(context, GAME_PREFIX + game.id, GameJson.encodeToString(Game.serializer(), game))
        }
    }

    private fun put(context: Context, path: String, json: String) {
        runCatching {
            val request = PutDataMapRequest.create(path).apply {
                dataMap.putString("json", json)
                dataMap.putLong("at", System.currentTimeMillis())
            }.asPutDataRequest().setUrgent()
            Wearable.getDataClient(context).putDataItem(request)
        }
    }
}

class WearListenerService : WearableListenerService() {
    private val main = Handler(Looper.getMainLooper())

    override fun onDataChanged(events: DataEventBuffer) {
        val engine = (application as WearApp).state.engine
        for (event in events) {
            if (event.type != DataEvent.TYPE_CHANGED || event.dataItem.uri.path != WearSync.SETTINGS_PATH) continue
            val json = DataMapItem.fromDataItem(event.dataItem).dataMap.getString("json") ?: continue
            main.post {
                runCatching { GameJson.decodeFromString(GameSettings.serializer(), json) }
                    .onSuccess(engine::receiveRemoteSettings)
            }
        }
    }
}
