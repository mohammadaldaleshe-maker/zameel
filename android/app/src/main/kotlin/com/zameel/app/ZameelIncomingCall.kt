package com.zameel.app

import android.app.*
import android.content.*
import android.media.AudioAttributes
import android.net.Uri
import android.os.*
import android.graphics.Color
import android.graphics.BitmapFactory
import android.graphics.drawable.Icon
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import android.widget.*

/** Native incoming UI works before Flutter has started. No microphone/camera
 * is opened until the user answers and Flutter validates the live session. */
object ZameelIncomingCall {
    private val imageWorker161 = Executors.newSingleThreadExecutor()
    private const val CHANNEL = "zameel_incoming_calls_v3"
    private const val SILENT = "zameel_incoming_calls_silent_v3"
    private fun prefs(c: Context) = c.getSharedPreferences("zameel_calls", Context.MODE_PRIVATE)
    private fun id(room: String) = ("call:$room").hashCode() and 0x7fffffff
    fun setUser(c: Context, user: String?) {
        val p = prefs(c)
        if (p.getString("user", null) != user) {
            p.getString("room", null)?.let { dismiss(c, it) }
        }
        p.edit().putString("user", user).apply()
    }
    fun isActive(c: Context, room: String): Boolean =
        prefs(c).getString("room", null) == room &&
        prefs(c).getLong("expires", 0) > System.currentTimeMillis()
    fun dismiss(c: Context, room: String) {
        prefs(c).edit().putLong("closed:$room", System.currentTimeMillis() + 120_000).apply()
        c.getSystemService(NotificationManager::class.java)?.cancel(id(room))
        if (prefs(c).getString("room", null) == room) {
            prefs(c).edit().remove("room").remove("expires").apply()
        }
    }
    fun receive(c: Context, b: Bundle): Boolean {
        val type = b.getString("type") ?: b.getString("notification_type") ?: ""
        if (type !in listOf("incoming_video_call", "incoming_voice_call", "call_ended")) return false
        val room = b.getString("room_id").orEmpty()
        if (room.isBlank()) return true
        if (type == "call_ended") { dismiss(c, room); return true }
        val recipient = b.getString("recipient_id").orEmpty()
        if (recipient.isEmpty() || recipient != prefs(c).getString("user", null)) return true
        val expires = b.getString("expires_at_ms")?.toLongOrNull() ?: return true
        val now = System.currentTimeMillis()
        if (prefs(c).getLong("closed:$room", 0) > now) return true
        if (expires <= now || expires > now + 50_000) return true
        if (isActive(c, room)) return true
        prefs(c).getString("room", null)?.let { dismiss(c, it) }
        prefs(c).edit().putString("room", room).putLong("expires", expires).apply()
        val name = b.getString("caller_name")?.takeIf { it.isNotBlank() } ?: "زميل"
        val video = type == "incoming_video_call"
        val sound = b.getString("play_sound") != "false"
        val manager = c.getSystemService(NotificationManager::class.java) ?: return true
        val soundUri = Uri.parse("android.resource://${c.packageName}/${R.raw.zameel_ringtone}")
        if (Build.VERSION.SDK_INT >= 26) {
            listOf(CHANNEL, SILENT).forEach { channel ->
                manager.createNotificationChannel(NotificationChannel(channel,
                    "مكالمات زميل الواردة", NotificationManager.IMPORTANCE_HIGH).apply {
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    enableVibration(true)
                    setSound(if (channel == CHANNEL) soundUri else null,
                        AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE).build())
                })
            }
        }
        fun pending(action: String): PendingIntent {
            val uri = Uri.Builder().scheme("zameel").authority("call")
                .appendQueryParameter("room_id", room)
                .appendQueryParameter("action", action)
                .appendQueryParameter("video", video.toString())
                .appendQueryParameter("caller_id", b.getString("caller_id"))
                .appendQueryParameter("caller_name", name).build()
            // Tapping the banner opens the app; only the explicit answer button accepts.
            val intent = if (action == "ring") Intent(c, MainActivity::class.java).setAction(Intent.ACTION_MAIN)
                else Intent(Intent.ACTION_VIEW, uri, c, MainActivity::class.java)
            intent.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            return PendingIntent.getActivity(c, id(room) xor action.hashCode(), intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        val ring = pending("ring")
        val answer = pending("accept")
        val decline = pending("decline")
        val builder = if (Build.VERSION.SDK_INT >= 26)
            Notification.Builder(c, if (sound) CHANNEL else SILENT) else Notification.Builder(c)
        builder.setSmallIcon(R.mipmap.ic_launcher).setContentTitle(name)
            .setContentText(if (video) "مكالمة فيديو واردة" else "مكالمة صوتية واردة")
            .setCategory(Notification.CATEGORY_CALL).setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true).setContentIntent(ring)
            .setOnlyAlertOnce(true)
        if (Build.VERSION.SDK_INT >= 26) builder.setTimeoutAfter(expires - now)
        if (Build.VERSION.SDK_INT >= 31) {
            val person = Person.Builder().setName(name).setImportant(true).setIcon(Icon.createWithResource(c, android.R.drawable.ic_menu_myplaces)).build()
            builder.setStyle(Notification.CallStyle.forIncomingCall(person, decline, answer).setIsVideo(video))
        } else {
            builder.addAction(Notification.Action.Builder(android.graphics.drawable.Icon.createWithResource(c, R.mipmap.ic_launcher), "رفض", decline).build())
                .addAction(Notification.Action.Builder(android.graphics.drawable.Icon.createWithResource(c, R.mipmap.ic_launcher), "رد", answer).build())
        }
        if (Build.VERSION.SDK_INT < 26) {
            builder.setPriority(Notification.PRIORITY_MAX)
            if (sound) builder.setSound(soundUri)
        }
        val notification = builder.build()
        if (sound) notification.flags = notification.flags or Notification.FLAG_INSISTENT
        try { manager.notify(id(room), notification) }
        catch (_: SecurityException) { dismiss(c, room) }
        val image = b.getString("caller_image").orEmpty()
        if (image.isNotEmpty()) imageWorker161.execute {
            if (!isActive(c, room)) return@execute
            val avatar = loadCallerImage161(image)
            if (avatar != null && isActive(c, room) && prefs(c).getString("user", null) == recipient) {
                builder.setLargeIcon(avatar).setOnlyAlertOnce(true)
                if (Build.VERSION.SDK_INT >= 31) {
                    val person = Person.Builder().setName(name).setImportant(true).setIcon(Icon.createWithBitmap(avatar)).build()
                    builder.setStyle(Notification.CallStyle.forIncomingCall(person, decline, answer).setIsVideo(video))
                }
                if (Build.VERSION.SDK_INT >= 26) builder.setTimeoutAfter((expires - System.currentTimeMillis()).coerceAtLeast(1))
                val updated = builder.build()
                if (sound) updated.flags = updated.flags or Notification.FLAG_INSISTENT
                try { manager.notify(id(room), updated) } catch (_: SecurityException) { }
            }
        }
        return true
    }
    private fun loadCallerImage161(value: String): android.graphics.Bitmap? {
        var connection: HttpURLConnection? = null
        return try {
            val url = URL(value)
            if (url.protocol != "https" || url.host != "jwuqyykjmltroneqtjoc.supabase.co" || !url.path.startsWith("/storage/v1/object/") || url.userInfo != null || value.length > 1800) return null
            connection = url.openConnection() as HttpURLConnection
            connection.connectTimeout = 2000; connection.readTimeout = 3000
            connection.instanceFollowRedirects = false
            if (connection.responseCode != 200 || connection.contentLengthLong > 2_000_000L) return null
            val bytes = connection.inputStream.use { input ->
                val output = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                while (output.size() <= 2_000_000) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    output.write(buffer, 0, read)
                }
                output.toByteArray()
            }
            if (bytes.size > 2_000_000) return null
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            val options = BitmapFactory.Options().apply { inSampleSize = 1 }
            while (bounds.outWidth / options.inSampleSize > 256 || bounds.outHeight / options.inSampleSize > 256) options.inSampleSize *= 2
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
        } catch (_: Exception) { null } finally {connection?.disconnect()}
    }

}

class ZameelIncomingCallActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) { super.onCreate(savedInstanceState); finish() }
}
