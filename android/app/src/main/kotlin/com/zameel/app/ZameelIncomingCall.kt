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
    private val images = Executors.newSingleThreadExecutor()
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
                .appendQueryParameter("caller_name", name)
                .appendQueryParameter("caller_image", b.getString("caller_image")).build()
            val target = if (action == "ring") ZameelIncomingCallActivity::class.java else MainActivity::class.java
            val intent = Intent(Intent.ACTION_VIEW, uri, c, target).apply {
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
            .setOngoing(true).setContentIntent(ring).setFullScreenIntent(ring, true)
            .setOnlyAlertOnce(true)
        if (Build.VERSION.SDK_INT >= 26) builder.setTimeoutAfter(expires - now)
        if (Build.VERSION.SDK_INT >= 31) {
            val person = Person.Builder().setName(name).setImportant(true).build()
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
        if (MainActivity.isVisible && isActive(c, room)) {
            try { ring.send() } catch (_: PendingIntent.CanceledException) {}
        }
        val image = b.getString("caller_image").orEmpty()
        if (image.isNotBlank()) images.execute {
            val avatar = loadCallerImage163(image)
            if (avatar != null && isActive(c, room) && prefs(c).getString("user", null) == recipient) {
                builder.setLargeIcon(avatar).setOnlyAlertOnce(true)
                if (Build.VERSION.SDK_INT >= 31) {
                    val person = Person.Builder().setName(name).setImportant(true).setIcon(Icon.createWithBitmap(avatar)).build()
                    builder.setStyle(Notification.CallStyle.forIncomingCall(person, decline, answer).setIsVideo(video))
                }
                if (Build.VERSION.SDK_INT >= 26) builder.setTimeoutAfter((expires-System.currentTimeMillis()).coerceAtLeast(1))
                try { manager.notify(id(room), builder.build()) } catch (_: SecurityException) { }
            }
        }
        return true
    }
    fun loadCallerImage163(value: String): android.graphics.Bitmap? {
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
    private val handler = Handler(Looper.getMainLooper())
    private var room = ""
    private val monitor = object : Runnable {
        override fun run() {
            if (!ZameelIncomingCall.isActive(this@ZameelIncomingCallActivity, room)) {
                ZameelIncomingCall.dismiss(this@ZameelIncomingCallActivity, room)
                finish()
            } else handler.postDelayed(this, 500)
        }
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 27) { setShowWhenLocked(true); setTurnScreenOn(true) }
        else window.addFlags(android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        room = intent.data?.getQueryParameter("room_id").orEmpty()
        if (!ZameelIncomingCall.isActive(this, room)) { finish(); return }
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = android.view.Gravity.CENTER
            setPadding(36, 48, 36, 48)
            setBackgroundColor(Color.rgb(20, 22, 27))
        }
        fun label(value: String, size: Float) = TextView(this).apply {
            text = value; textSize = size; setTextColor(Color.WHITE)
            gravity = android.view.Gravity.CENTER
            setPadding(8, 24, 8, 24)
        }
        layout.addView(label("Zameel — زميل", 20f))
        val avatar = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_menu_myplaces)
            scaleType = ImageView.ScaleType.CENTER_CROP
            background = android.graphics.drawable.GradientDrawable().apply { shape = android.graphics.drawable.GradientDrawable.OVAL; setColor(Color.DKGRAY) }
            clipToOutline = true
        }
        val side = (112 * resources.displayMetrics.density).toInt()
        layout.addView(avatar, LinearLayout.LayoutParams(side, side).apply { gravity = android.view.Gravity.CENTER_HORIZONTAL })
        val image = intent.data?.getQueryParameter("caller_image").orEmpty()
        if (image.isNotBlank()) Thread {
            val bitmap = ZameelIncomingCall.loadCallerImage163(image)
            runOnUiThread { if (!isFinishing && ZameelIncomingCall.isActive(this, room) && bitmap != null) avatar.setImageBitmap(bitmap) }
        }.start()
        layout.addView(label(intent.data?.getQueryParameter("caller_name") ?: "زميل", 30f))
        layout.addView(label(if (intent.data?.getQueryParameter("video") == "true")
            "مكالمة فيديو واردة" else "مكالمة صوتية واردة", 20f))
        val actions = LinearLayout(this).apply { gravity = android.view.Gravity.CENTER }
        for ((title, action) in listOf("رفض" to "decline", "رد" to "accept")) {
            val button = Button(this).apply {
                text = title; textSize = 20f
                setOnClickListener { respond(action) }
            }
            actions.addView(button, LinearLayout.LayoutParams(0, 90, 1f).apply { setMargins(12, 24, 12, 24) })
        }
        layout.addView(actions, LinearLayout.LayoutParams(-1, -2))
        setContentView(layout)
        handler.post(monitor)
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        recreate()
    }
    private fun respond(action: String) {
        if (!ZameelIncomingCall.isActive(this, room)) { finish(); return }
        handler.removeCallbacksAndMessages(null)
        ZameelIncomingCall.dismiss(this, room)
        val uri = intent.data?.buildUpon()?.clearQuery()
            ?.appendQueryParameter("room_id", room)
            ?.appendQueryParameter("action", action)
            ?.appendQueryParameter("video", intent.data?.getQueryParameter("video"))
            ?.appendQueryParameter("caller_id", intent.data?.getQueryParameter("caller_id"))
            ?.appendQueryParameter("caller_name", intent.data?.getQueryParameter("caller_name"))?.build()
        val launch = Intent(Intent.ACTION_VIEW, uri, this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        // Answer requires unlocking before accessing microphone/camera/session.
        val keyguard = getSystemService(KeyguardManager::class.java)
        if (action == "accept" && Build.VERSION.SDK_INT >= 26 && keyguard?.isKeyguardLocked == true) {
            keyguard.requestDismissKeyguard(this, object : KeyguardManager.KeyguardDismissCallback() {
                override fun onDismissSucceeded() { startActivity(launch); finish() }
                override fun onDismissCancelled() { finish() }
                override fun onDismissError() { finish() }
            })
        } else { startActivity(launch); finish() }
    }
    override fun onDestroy() { handler.removeCallbacksAndMessages(null); super.onDestroy() }
}
