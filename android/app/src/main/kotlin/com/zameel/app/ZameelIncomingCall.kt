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
    private val notifications = mutableMapOf<String, Notification>()
    private var visibleRoom: String? = null
    private val imageLoadLock = Any()
    private val avatars = android.util.LruCache<String, android.graphics.Bitmap>(6)
    private const val COVERED = "zameel_call_screen_visible_v1"
    private val images = Executors.newSingleThreadExecutor()
    private const val CHANNEL = "zameel_incoming_calls_v3"
    private const val SILENT = "zameel_incoming_calls_silent_v3"
    private fun prefs(c: Context) = c.getSharedPreferences("zameel_calls", Context.MODE_PRIVATE)
    private fun id(room: String) = ("call:$room").hashCode() and 0x7fffffff
    fun isLocked(c: Context): Boolean =
        c.getSystemService(KeyguardManager::class.java)?.isKeyguardLocked == true

    fun fallbackAvatar(name: String): android.graphics.Bitmap {
        val bitmap = android.graphics.Bitmap.createBitmap(128, 128, android.graphics.Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(bitmap)
        canvas.drawColor(Color.rgb(183, 227, 241))
        val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(20, 22, 27); textSize = 60f; textAlign = android.graphics.Paint.Align.CENTER
        }
        val letter = name.trim().take(1).ifBlank { "ز" }
        canvas.drawText(letter, 64f, 64f - (paint.ascent() + paint.descent()) / 2, paint)
        return bitmap
    }

    @Synchronized
    private fun publish(c: Context, room: String, notification: Notification) {
        if (!isActive(c, room)) return
        notifications[room] = notification
        val manager = c.getSystemService(NotificationManager::class.java) ?: return
        val shown = if (visibleRoom == room) {
            val quiet = Notification.Builder.recoverBuilder(c, notification.clone())
                .setFullScreenIntent(null, false).setOnlyAlertOnce(true)
            if (Build.VERSION.SDK_INT >= 26) quiet.setChannelId(COVERED)
            else quiet.setPriority(Notification.PRIORITY_LOW).setSound(null).setVibrate(null)
            quiet.build().apply { flags = flags and Notification.FLAG_INSISTENT.inv() }
        } else notification
        // Android 14+ can remove a disallowed FSI before validating CallStyle.
        val permitted = Build.VERSION.SDK_INT < 34 || manager.canUseFullScreenIntent()
        val safe = if (shown.fullScreenIntent == null || !permitted)
            standardNotification(c, shown) else shown
        try {
            manager.notify(id(room), safe)
        } catch (error: IllegalArgumentException) {
            android.util.Log.e("ZameelCalls", "Call notification rejected; retrying standard template", error)
            try {
                manager.notify(id(room), standardNotification(c, safe))
            } catch (fallback: IllegalArgumentException) {
                android.util.Log.e("ZameelCalls", "Standard call notification rejected", fallback)
            } catch (denied: SecurityException) {
                android.util.Log.e("ZameelCalls", "Call notification permission denied", denied)
            }
        } catch (denied: SecurityException) {
            android.util.Log.e("ZameelCalls", "Call notification permission denied", denied)
        }
    }

    private fun standardNotification(c: Context, source: Notification): Notification {
        // Recovered actions retain the original answer/decline PendingIntents.
        // Replace the template when FSI is absent; keeping CallStyle here crashes Android.
        return Notification.Builder.recoverBuilder(c, source.clone())
            .setFullScreenIntent(null, false)
            .setStyle(Notification.BigTextStyle().bigText(source.extras.getCharSequence(Notification.EXTRA_TEXT)))
            .build().apply {
                flags = if (source.flags and Notification.FLAG_INSISTENT != 0)
                    flags or Notification.FLAG_INSISTENT else flags and Notification.FLAG_INSISTENT.inv()
            }
    }

    @Synchronized
    fun screenVisible(c: Context, room: String) {
        if (!isActive(c, room) || visibleRoom == room) return
        val manager = c.getSystemService(NotificationManager::class.java)
        if (!notifications.containsKey(room)) {
            manager?.activeNotifications?.firstOrNull { it.id == id(room) }
                ?.notification?.let { notifications[room] = it }
        }
        visibleRoom = room
        // Remove the existing heads-up card before replacing it on a quiet channel.
        c.getSystemService(NotificationManager::class.java)?.cancel(id(room))
        notifications[room]?.let { publish(c, room, it) }
    }

    @Synchronized
    fun screenHidden(c: Context, room: String) {
        if (visibleRoom != room) return
        visibleRoom = null
        if (!isActive(c, room)) return
        notifications[room]?.let {
            // Returning to the notification must never launch the Activity again.
            val builder = Notification.Builder.recoverBuilder(c, it.clone())
                .setFullScreenIntent(null, false).setOnlyAlertOnce(true)
            c.getSystemService(NotificationManager::class.java)?.cancel(id(room))
            publish(c, room, builder.build())
        }
    }

    fun shouldSound(c: Context, room: String): Boolean =
        isActive(c, room) && prefs(c).getBoolean("sound", true)

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
    @Synchronized
    fun dismiss(c: Context, room: String) {
        notifications.remove(room)
        if (visibleRoom == room) visibleRoom = null
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
        val now = System.currentTimeMillis()
        // Prefer the server-measured time left (ttl_ms) so a phone clock that is
        // slightly off cannot silently drop a real call. Older pushes without it
        // keep using the absolute expiry.
        val ttl = b.getString("ttl_ms")?.toLongOrNull()
        val expires = if (ttl != null && ttl > 0 && ttl <= 50_000) now + ttl
            else b.getString("expires_at_ms")?.toLongOrNull() ?: return true
        if (prefs(c).getLong("closed:$room", 0) > now) return true
        if (expires <= now || expires > now + 50_000) return true
        if (isActive(c, room)) return true
        prefs(c).getString("room", null)?.let { dismiss(c, it) }
        prefs(c).edit().putString("room", room).putLong("expires", expires).apply()
        val name = b.getString("caller_name")?.takeIf { it.isNotBlank() } ?: "زميل"
        val video = type == "incoming_video_call"
        val sound = b.getString("play_sound") != "false"
        prefs(c).edit().putBoolean("sound", sound).apply()
        val manager = c.getSystemService(NotificationManager::class.java) ?: return true
        val soundUri = Uri.parse("android.resource://${c.packageName}/${R.raw.zameel_ringtone}")
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(COVERED,
                "مكالمة زميل المعروضة", NotificationManager.IMPORTANCE_LOW).apply {
                setSound(null, null); enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            })
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
            .setOngoing(true).setContentIntent(ring)
            .setOnlyAlertOnce(true)
        // CallStyle requires a full-screen intent even while unlocked. Android chooses
        // heads-up vs full-screen; never launch the Activity ourselves.
        builder.setFullScreenIntent(ring, true)
        val placeholder = fallbackAvatar(name)
        builder.setLargeIcon(placeholder)
        if (Build.VERSION.SDK_INT >= 26) builder.setTimeoutAfter(expires - now)
        if (Build.VERSION.SDK_INT >= 31) {
            val person = Person.Builder().setName(name).setImportant(true).setIcon(Icon.createWithBitmap(placeholder)).build()
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
        publish(c, room, notification)
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
                val updated = builder.build()
                if (sound) updated.flags = updated.flags or Notification.FLAG_INSISTENT
                publish(c, room, updated)
            }
        }
        return true
    }
    fun loadCallerImage163(value: String): android.graphics.Bitmap? =
        synchronized(imageLoadLock) { loadCallerImageBytes163(value) }

    private fun loadCallerImageBytes163(value: String): android.graphics.Bitmap? {
        synchronized(avatars) { avatars.get(value)?.let { return it } }
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
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)?.also {
                synchronized(avatars) { avatars.put(value, it) }
            }
        } catch (_: Exception) { null } finally {connection?.disconnect()}
    }
}

class ZameelIncomingCallActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private var room = ""
    private var ringtone: android.media.Ringtone? = null
    private var responding = false
    private var openedWhileLocked = false
    private fun dp(value: Int): Int = (value * resources.displayMetrics.density + 0.5f).toInt()

    private val monitor = object : Runnable {
        override fun run() {
            if (!ZameelIncomingCall.isActive(this@ZameelIncomingCallActivity, room)) {
                ZameelIncomingCall.dismiss(this@ZameelIncomingCallActivity, room)
                finish()
            } else if (openedWhileLocked && !responding &&
                !ZameelIncomingCall.isLocked(this@ZameelIncomingCallActivity)) {
                finish()
            } else handler.postDelayed(this, 500)
        }
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        openedWhileLocked = ZameelIncomingCall.isLocked(this)
        if (Build.VERSION.SDK_INT >= 27) { setShowWhenLocked(true); setTurnScreenOn(true) }
        else window.addFlags(android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        room = intent.data?.getQueryParameter("room_id").orEmpty()
        if (!ZameelIncomingCall.isActive(this, room)) { finish(); return }
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = android.view.Gravity.CENTER
            setPadding(dp(24), dp(24), dp(24), dp(24))
            layoutDirection = android.view.View.LAYOUT_DIRECTION_RTL
            setBackgroundColor(Color.rgb(20, 22, 27))
        }
        fun label(value: String, size: Float) = TextView(this).apply {
            text = value; textSize = size; setTextColor(Color.WHITE)
            gravity = android.view.Gravity.CENTER
            setPadding(8, 24, 8, 24)
        }
        layout.addView(label("Zameel — زميل", 20f))
        val callerName = intent.data?.getQueryParameter("caller_name")?.takeIf { it.isNotBlank() } ?: "زميل"
        val avatar = ImageView(this).apply {
            setImageBitmap(ZameelIncomingCall.fallbackAvatar(callerName))
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
        layout.addView(label(callerName, 26f))
        layout.addView(label(if (intent.data?.getQueryParameter("video") == "true")
            "مكالمة فيديو واردة" else "مكالمة صوتية واردة", 20f))
        val actions = LinearLayout(this).apply {
            gravity = android.view.Gravity.CENTER
            orientation = LinearLayout.HORIZONTAL
        }
        for ((title, action) in listOf("رفض" to "decline", "رد" to "accept")) {
            val button = Button(this).apply {
                text = title; textSize = 18f; isAllCaps = false
                minHeight = dp(56); minimumHeight = dp(56)
                setPadding(dp(8), dp(8), dp(8), dp(8))
                gravity = android.view.Gravity.CENTER
                setTextColor(Color.WHITE)
                background = android.graphics.drawable.GradientDrawable().apply {
                    cornerRadius = dp(28).toFloat()
                    setColor(if (action == "accept") Color.rgb(64, 166, 109) else Color.rgb(218, 86, 78))
                }
                setOnClickListener {
                    if (!responding) { responding = true; respond(action) }
                }
            }
            actions.addView(button, LinearLayout.LayoutParams(0, -2, 1f).apply { setMargins(dp(6), dp(12), dp(6), dp(12)) })
        }
        layout.addView(actions, LinearLayout.LayoutParams(-1, -2))
        val scroll = ScrollView(this).apply { isFillViewport = true; addView(layout) }
        val host = FrameLayout(this).apply {
            setBackgroundColor(Color.rgb(20, 22, 27))
            addView(scroll, FrameLayout.LayoutParams(-1, -1))
        }
        host.setOnApplyWindowInsetsListener { view, insets ->
            @Suppress("DEPRECATION")
            view.setPadding(insets.systemWindowInsetLeft, insets.systemWindowInsetTop,
                insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
            insets
        }
        showCallScreen(host)
        host.requestApplyInsets()
        handler.post(monitor)
    }
    private fun showCallScreen(layout: android.view.View) { setContentView(layout) }

    override fun onStart() {
        super.onStart()
        if (!ZameelIncomingCall.isActive(this, room)) { finish(); return }
        ZameelIncomingCall.screenVisible(this, room)
        if (ZameelIncomingCall.shouldSound(this, room)) {
            try {
                val uri = Uri.parse("android.resource://$packageName/${R.raw.zameel_ringtone}")
                ringtone = android.media.RingtoneManager.getRingtone(this, uri)?.apply {
                    audioAttributes = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE).build()
                    if (Build.VERSION.SDK_INT >= 28) isLooping = true
                    play()
                }
            } catch (_: Exception) { }
        }
    }
    private fun stopRinging() { ringtone?.stop(); ringtone = null }
    override fun onStop() {
        stopRinging()
        ZameelIncomingCall.screenHidden(this, room)
        super.onStop()
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        recreate()
    }
    private fun respond(action: String) {
        if (!ZameelIncomingCall.isActive(this, room)) { finish(); return }
        handler.removeCallbacksAndMessages(null)
        stopRinging()
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
        // A voice call can be answered and spoken on without unlocking: the call
        // screen is shown over the lock screen (like other calling apps). Video
        // asks to unlock once, because the camera needs the unlocked phone.
        val keyguard = getSystemService(KeyguardManager::class.java)
        val isVideo = intent.data?.getQueryParameter("video") == "true"
        if (action == "accept" && isVideo && Build.VERSION.SDK_INT >= 26 && keyguard?.isKeyguardLocked == true) {
            keyguard.requestDismissKeyguard(this, object : KeyguardManager.KeyguardDismissCallback() {
                override fun onDismissSucceeded() { startActivity(launch); finish() }
                override fun onDismissCancelled() { finish() }
                override fun onDismissError() { finish() }
            })
        } else { startActivity(launch); finish() }
    }
    override fun onDestroy() { stopRinging(); handler.removeCallbacksAndMessages(null); super.onDestroy() }
}
