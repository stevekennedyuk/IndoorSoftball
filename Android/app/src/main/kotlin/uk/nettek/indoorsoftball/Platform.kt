package uk.nettek.indoorsoftball

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.content.FileProvider
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import uk.nettek.indoorsoftball.shared.Game
import uk.nettek.indoorsoftball.shared.GameEngine
import uk.nettek.indoorsoftball.shared.GameJson
import uk.nettek.indoorsoftball.shared.GameSettings
import uk.nettek.indoorsoftball.shared.exportFileName
import uk.nettek.indoorsoftball.shared.resultsDocument
import uk.nettek.indoorsoftball.shared.shareSubject
import java.io.File

// ---------------------------------------------------------------- results files

/**
 * Saves each finished game as a text document in the app's private storage,
 * named home-away-location-date&time. Files leave the app only when the user
 * shares one or saves a copy.
 */
class ResultsArchive(private val context: Context, private val dir: File) {
    fun file(game: Game) = File(dir, game.exportFileName())

    fun save(game: Game): File? = runCatching {
        dir.mkdirs()
        file(game).apply { writeText(game.resultsDocument()) }
    }.getOrNull()

    /** The game's file, creating it if it isn't there. */
    fun ensureFile(game: Game): File? = file(game).takeIf { it.exists() } ?: save(game)

    fun delete(game: Game) {
        runCatching { file(game).delete() }
    }

    /** Opens the share sheet with the results document attached and its text as the message. */
    fun share(game: Game) {
        val file = ensureFile(game) ?: return
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, game.shareSubject())
            putExtra(Intent.EXTRA_TEXT, game.resultsDocument())
            clipData = ClipData.newRawUri(file.name, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(
            Intent.createChooser(send, "Share results").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }

    /** Writes the document to a location the user picked with the system file picker. */
    fun saveCopy(game: Game, to: Uri) {
        runCatching {
            context.contentResolver.openOutputStream(to)?.use { it.write(game.resultsDocument().toByteArray()) }
        }
    }
}

// ---------------------------------------------------------------- clock alerts

/**
 * "Nearly time" and "TIME!" alerts for when the app is in the background.
 * (While the app is on screen it vibrates and beeps itself.)
 */
object Alerts {
    private const val CHANNEL = "clock"
    private const val WARNING = 1
    private const val TIME_UP = 2

    fun createChannel(context: Context) {
        val channel = NotificationChannel(CHANNEL, "Half-inning clock", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Alerts when a half inning is nearly over or has ended"
            enableVibration(true)
        }
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun pending(context: Context, id: Int, title: String = "", text: String = ""): PendingIntent {
        val intent = Intent(context, AlertReceiver::class.java)
            .putExtra("id", id).putExtra("title", title).putExtra("text", text)
        return PendingIntent.getBroadcast(
            context, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun schedule(context: Context, timeUpAt: Long?, warningAt: Long?, halfLabel: String) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        alarms.cancel(pending(context, WARNING))
        alarms.cancel(pending(context, TIME_UP))
        context.getSystemService(NotificationManager::class.java).apply {
            cancel(WARNING)
            cancel(TIME_UP)
        }
        val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarms.canScheduleExactAlarms()
        fun set(at: Long, intent: PendingIntent) {
            if (at <= System.currentTimeMillis() + 1000) return
            runCatching {
                if (exact) alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent)
                else alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent)
            }
        }
        warningAt?.let { set(it, pending(context, WARNING, "Nearly time", "$halfLabel is nearly over.")) }
        timeUpAt?.let {
            set(it, pending(context, TIME_UP, "TIME!", "$halfLabel is over. Enter any last scores, then start the next half."))
        }
    }

    fun post(context: Context, id: Int, title: String, text: String) {
        val open = PendingIntent.getActivity(
            context, 0, Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(open)
            .build()
        // Fails quietly if the user hasn't allowed notifications.
        runCatching { context.getSystemService(NotificationManager::class.java).notify(id, notification) }
    }
}

class AlertReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val state = (context.applicationContext as IndoorSoftballApp).state
        if (state.inForeground) return // the app has already buzzed and beeped
        Alerts.post(
            context, intent.getIntExtra("id", 0),
            intent.getStringExtra("title") ?: "", intent.getStringExtra("text") ?: ""
        )
    }
}

// ---------------------------------------------------------------- phone ↔ watch sync

/**
 * Keeps the phone and the Wear OS watch in step through the Wearable Data Layer:
 * settings are copied both ways, and games finished on the watch arrive here,
 * where they are added to History and saved as results files. Each device
 * scores its own game. Does nothing if there is no watch.
 */
object WearSync {
    const val SETTINGS_PATH = "/settings"
    const val GAME_PREFIX = "/game/"

    fun attach(context: Context, engine: GameEngine) {
        engine.onSettingsChanged = { settings ->
            runCatching {
                val request = PutDataMapRequest.create(SETTINGS_PATH).apply {
                    dataMap.putString("json", GameJson.encodeToString(GameSettings.serializer(), settings))
                    dataMap.putLong("at", System.currentTimeMillis())
                }.asPutDataRequest().setUrgent()
                Wearable.getDataClient(context).putDataItem(request)
            }
        }
    }
}

class WearListenerService : WearableListenerService() {
    private val main = Handler(Looper.getMainLooper())

    override fun onDataChanged(events: DataEventBuffer) {
        val engine = (application as IndoorSoftballApp).state.engine
        for (event in events) {
            if (event.type != DataEvent.TYPE_CHANGED) continue
            val uri = event.dataItem.uri
            val path = uri.path ?: continue
            val json = DataMapItem.fromDataItem(event.dataItem).dataMap.getString("json") ?: continue
            when {
                path == WearSync.SETTINGS_PATH -> main.post {
                    runCatching { GameJson.decodeFromString(GameSettings.serializer(), json) }
                        .onSuccess(engine::receiveRemoteSettings)
                }
                path.startsWith(WearSync.GAME_PREFIX) -> main.post {
                    runCatching { GameJson.decodeFromString(Game.serializer(), json) }.onSuccess {
                        engine.receiveRemoteGame(it)
                        // Received and saved: clear it from the sync store.
                        Wearable.getDataClient(this).deleteDataItems(uri)
                    }
                }
            }
        }
    }
}
