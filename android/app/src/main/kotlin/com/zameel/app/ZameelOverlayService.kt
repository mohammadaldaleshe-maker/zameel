package com.zameel.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView
import kotlin.math.abs

/**
 * Short-lived host for Zameel's real app-over-app chat head.
 *
 * The service is NOT kept alive while Zameel is merely open. It starts only
 * for a real incoming direct message, uses that message notification as its
 * foreground notification (with the Zameel sound), shows the overlay, and
 * stops when the overlay is dismissed or Zameel is opened. If Android refuses
 * the background foreground-service start, the receiver falls back to the
 * official Android Conversation/Bubble notification path.
 */
class ZameelOverlayService : Service() {
    companion object {
        private const val ACTION_SHOW = "com.zameel.app.overlay.SHOW"
        private const val ACTION_SHOW_BROADCAST = "com.zameel.app.overlay.SHOW_BROADCAST"
        private const val ACTION_HIDE_AND_STOP_BROADCAST =
            "com.zameel.app.overlay.HIDE_AND_STOP_BROADCAST"
        private const val EXTRA_KEEP_MESSAGE_NOTIFICATION = "keep_message_notification"

        private const val SERVICE_CHANNEL = "zameel_floating_bubble_message_v3"
        private const val SERVICE_SILENT_CHANNEL = "zameel_floating_bubble_message_silent_v3"
        private const val SERVICE_NOTIFICATION_ID = 0x5A42

        private const val PREFS = "zameel_overlay"
        private const val PREF_X = "x"
        private const val PREF_Y = "y"
        private const val PREF_OVERLAY_VERIFIED = "overlay_verified"

        private const val EXTRA_CONVERSATION_ID = "conversation_id"
        private const val EXTRA_SENDER_ID = "sender_id"
        private const val EXTRA_SENDER_NAME = "sender_name"
        private const val EXTRA_SENDER_AVATAR = "sender_avatar"
        private const val EXTRA_PREVIEW = "message_preview"
        private const val EXTRA_PLAY_SOUND = "play_sound"

        @Volatile
        private var serviceRunning = false

        fun canDrawOverlays(context: Context): Boolean {
            return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context)
        }

        /**
         * Called only for a real direct-message FCM. If the short-lived service
         * already exists, update it in-process. Otherwise use the FCM exemption
         * to start it. A false return tells the receiver to post the official
         * Conversation/Bubble notification instead.
         */
        fun showFromPush(context: Context, extras: Bundle): Boolean {
            if (!canDrawOverlays(context)) return false
            val conversationId = value(extras, EXTRA_CONVERSATION_ID)
            if (conversationId.isBlank()) return false

            if (serviceRunning) {
                return try {
                    context.sendBroadcast(
                        Intent(ACTION_SHOW_BROADCAST).apply {
                            setPackage(context.packageName)
                            putExtras(Bundle(extras))
                        },
                    )
                    true
                } catch (error: Throwable) {
                    Log.w("ZameelOverlay", "Could not update active message bubble", error)
                    false
                }
            }

            val serviceIntent = Intent(context, ZameelOverlayService::class.java).apply {
                action = ACTION_SHOW
                putExtras(Bundle(extras))
            }
            return try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
                true
            } catch (error: Throwable) {
                Log.w("ZameelOverlay", "Could not start message bubble service from push", error)
                false
            }
        }

        /** Hide a currently visible chat head and stop its short-lived service. */
        fun hideBubbleAndStop(context: Context, keepMessageNotification: Boolean) {
            if (!serviceRunning) return
            try {
                context.sendBroadcast(
                    Intent(ACTION_HIDE_AND_STOP_BROADCAST).apply {
                        setPackage(context.packageName)
                        putExtra(EXTRA_KEEP_MESSAGE_NOTIFICATION, keepMessageNotification)
                    },
                )
            } catch (_: Throwable) {
            }
        }

        fun isOverlayVerified(context: Context): Boolean =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getBoolean(PREF_OVERLAY_VERIFIED, false)

        private fun value(extras: Bundle, key: String): String =
            extras.get(key)?.toString()?.trim().orEmpty()
    }

    private lateinit var windowManager: WindowManager
    private var bubbleView: View? = null
    private var activeConversationId = ""
    private var activeSenderId = ""
    private var activeSenderName = "Zameel"
    private var activeSenderAvatar = ""
    private var receiverRegistered = false
    private var foregroundStarted = false

    private val commandReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                ACTION_SHOW_BROADCAST -> handleShow(intent.extras)
                ACTION_HIDE_AND_STOP_BROADCAST -> {
                    val keepNotification =
                        intent.getBooleanExtra(EXTRA_KEEP_MESSAGE_NOTIFICATION, true)
                    hideAndStop(keepNotification)
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        ensureServiceChannels()
        registerCommandReceiver()
        serviceRunning = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_SHOW) {
            handleShow(intent.extras)
        } else {
            // A message-triggered service should never stay alive without a real
            // message payload. This also prevents Android from resurrecting a
            // permanent "ready" host after process cleanup.
            stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun handleShow(extras: Bundle?) {
        if (extras == null) {
            stopSelf()
            return
        }

        activeConversationId = value(extras, EXTRA_CONVERSATION_ID)
        activeSenderId = value(extras, EXTRA_SENDER_ID)
        activeSenderName = value(extras, EXTRA_SENDER_NAME).ifBlank { "Zameel" }
        activeSenderAvatar = value(extras, EXTRA_SENDER_AVATAR)
        val preview = value(extras, EXTRA_PREVIEW)
            .ifBlank { value(extras, "body") }
            .ifBlank { "New message" }
        val playSound = value(extras, EXTRA_PLAY_SOUND).lowercase() != "false"

        if (activeConversationId.isBlank()) {
            stopSelf()
            return
        }

        // The foreground notification IS the actual incoming-message alert.
        // There is no permanent service-ready notification.
        val messageNotification = buildMessageNotification(preview, playSound)
        startForeground(SERVICE_NOTIFICATION_ID, messageNotification)
        foregroundStarted = true

        if (!canDrawOverlays(this)) {
            replaceWithConversationFallback(preview, playSound)
            return
        }

        try {
            showOrUpdateBubble(activeSenderName)
        } catch (error: Throwable) {
            Log.w("ZameelOverlay", "Floating overlay failed; using conversation notification", error)
            replaceWithConversationFallback(preview, playSound)
        }
    }

    private fun replaceWithConversationFallback(preview: String, playSound: Boolean) {
        removeBubble()
        removeForegroundNotification()
        postFallbackNotification(preview, playSound)
        stopSelf()
    }

    private fun postFallbackNotification(preview: String, playSound: Boolean) {
        val fallback = Bundle().apply {
            putString("type", "message")
            putString(EXTRA_CONVERSATION_ID, activeConversationId)
            putString(EXTRA_SENDER_ID, activeSenderId)
            putString(EXTRA_SENDER_NAME, activeSenderName)
            putString(EXTRA_SENDER_AVATAR, activeSenderAvatar)
            putString(EXTRA_PREVIEW, preview)
            putString(EXTRA_PLAY_SOUND, playSound.toString())
        }
        try {
            ZameelBubbleReceiver().postConversationFallback(this, fallback)
        } catch (error: Throwable) {
            Log.w("ZameelOverlay", "Conversation fallback notification also failed", error)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        serviceRunning = false
        removeBubble()
        if (receiverRegistered) {
            try {
                unregisterReceiver(commandReceiver)
            } catch (_: Throwable) {
            }
            receiverRegistered = false
        }
        super.onDestroy()
    }

    private fun registerCommandReceiver() {
        if (receiverRegistered) return
        val filter = IntentFilter().apply {
            addAction(ACTION_SHOW_BROADCAST)
            addAction(ACTION_HIDE_AND_STOP_BROADCAST)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(commandReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(commandReceiver, filter)
        }
        receiverRegistered = true
    }

    private fun showOrUpdateBubble(senderName: String) {
        removeBubble()

        val size = dp(68)
        val badgeSize = dp(22)
        val root = FrameLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(size, size)
            elevation = dp(10).toFloat()
        }

        val circle = TextView(this).apply {
            text = senderName.firstOrNull()?.uppercaseChar()?.toString() ?: "Z"
            gravity = Gravity.CENTER
            textSize = 27f
            setTextColor(Color.WHITE)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.rgb(49, 82, 232))
                setStroke(dp(3), Color.WHITE)
            }
            contentDescription = "Zameel message from $senderName"
        }
        root.addView(circle, FrameLayout.LayoutParams(size, size))

        val badge = TextView(this).apply {
            text = "Z"
            gravity = Gravity.CENTER
            textSize = 11f
            setTextColor(Color.WHITE)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.rgb(75, 35, 183))
                setStroke(dp(2), Color.WHITE)
            }
        }
        root.addView(
            badge,
            FrameLayout.LayoutParams(badgeSize, badgeSize, Gravity.END or Gravity.BOTTOM),
        )

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        val maxX = (resources.displayMetrics.widthPixels - size).coerceAtLeast(0)
        val maxY = (resources.displayMetrics.heightPixels - size).coerceAtLeast(0)
        val params = WindowManager.LayoutParams(
            size,
            size,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = prefs.getInt(PREF_X, dp(16)).coerceIn(0, maxX)
            y = prefs.getInt(PREF_Y, dp(180)).coerceIn(0, maxY)
        }

        installTouchBehavior(root, params)
        bubbleView = root
        windowManager.addView(root, params)
        getSharedPreferences(PREFS, MODE_PRIVATE)
            .edit()
            .putBoolean(PREF_OVERLAY_VERIFIED, true)
            .apply()
    }

    private fun installTouchBehavior(view: View, params: WindowManager.LayoutParams) {
        var startX = 0
        var startY = 0
        var touchX = 0f
        var touchY = 0f
        var downAt = 0L
        var moved = false

        view.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    startX = params.x
                    startY = params.y
                    touchX = event.rawX
                    touchY = event.rawY
                    downAt = System.currentTimeMillis()
                    moved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - touchX).toInt()
                    val dy = (event.rawY - touchY).toInt()
                    if (abs(dx) > dp(4) || abs(dy) > dp(4)) moved = true
                    val maxX = (resources.displayMetrics.widthPixels - params.width).coerceAtLeast(0)
                    val maxY = (resources.displayMetrics.heightPixels - params.height).coerceAtLeast(0)
                    params.x = (startX + dx).coerceIn(0, maxX)
                    params.y = (startY + dy).coerceIn(0, maxY)
                    bubbleView?.let { windowManager.updateViewLayout(it, params) }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    val heldMs = System.currentTimeMillis() - downAt
                    if (!moved && heldMs >= 650) {
                        // Long-press hides only the chat head. Keep the actual
                        // incoming-message notification visible for the unread message.
                        hideAndStop(keepMessageNotification = true)
                    } else if (!moved) {
                        openConversation()
                    } else {
                        savePosition(params)
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun openConversation() {
        val deepLink = Uri.Builder()
            .scheme("zameel")
            .authority("chat")
            .appendQueryParameter("conversation_id", activeConversationId)
            .appendQueryParameter("partner_id", activeSenderId)
            .appendQueryParameter("partner_name", activeSenderName)
            .build()
        val target = Intent(Intent.ACTION_VIEW, deepLink, this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        startActivity(target)
        hideAndStop(keepMessageNotification = false)
    }

    private fun savePosition(params: WindowManager.LayoutParams) {
        getSharedPreferences(PREFS, MODE_PRIVATE)
            .edit()
            .putInt(PREF_X, params.x)
            .putInt(PREF_Y, params.y)
            .apply()
    }

    private fun removeBubble() {
        val view = bubbleView ?: return
        try {
            windowManager.removeView(view)
        } catch (_: Throwable) {
        } finally {
            bubbleView = null
        }
    }

    private fun hideAndStop(keepMessageNotification: Boolean) {
        removeBubble()
        if (keepMessageNotification) {
            detachForegroundNotification()
        } else {
            removeForegroundNotification()
        }
        stopSelf()
    }

    private fun detachForegroundNotification() {
        if (!foregroundStarted) return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_DETACH)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(false)
            }
        } catch (_: Throwable) {
        } finally {
            foregroundStarted = false
        }
    }

    private fun removeForegroundNotification() {
        if (foregroundStarted) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
            } catch (_: Throwable) {
            } finally {
                foregroundStarted = false
            }
        }
        try {
            getSystemService(NotificationManager::class.java)?.cancel(SERVICE_NOTIFICATION_ID)
        } catch (_: Throwable) {
        }
    }

    private fun buildMessageNotification(preview: String, playSound: Boolean): Notification {
        val deepLink = Uri.Builder()
            .scheme("zameel")
            .authority("chat")
            .appendQueryParameter("conversation_id", activeConversationId)
            .appendQueryParameter("partner_id", activeSenderId)
            .appendQueryParameter("partner_name", activeSenderName)
            .build()
        val openIntent = Intent(Intent.ACTION_VIEW, deepLink, this, ZameelBubbleActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_DOCUMENT or Intent.FLAG_ACTIVITY_MULTIPLE_TASK
        }
        val pending = PendingIntent.getActivity(
            this,
            SERVICE_NOTIFICATION_ID,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(
                this,
                if (playSound) SERVICE_CHANNEL else SERVICE_SILENT_CHANNEL,
            )
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(activeSenderName)
            .setContentText(preview)
            .setContentIntent(pending)
            .setAutoCancel(true)
            .setOnlyAlertOnce(false)
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setColor(Color.rgb(49, 82, 232))
            .setWhen(System.currentTimeMillis())
            .setShowWhen(true)

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            builder.setPriority(Notification.PRIORITY_HIGH)
            if (playSound) builder.setSound(thunderSoundUri())
        }
        return builder.build()
    }

    private fun ensureServiceChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_COMMUNICATION_INSTANT)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val message = NotificationChannel(
            SERVICE_CHANNEL,
            "Zameel floating chat messages",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Incoming Zameel messages shown with the floating chat head"
            enableVibration(true)
            setSound(thunderSoundUri(), attributes)
            setShowBadge(true)
        }
        manager.createNotificationChannel(message)

        val silent = NotificationChannel(
            SERVICE_SILENT_CHANNEL,
            "Zameel floating chat messages (silent)",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Incoming Zameel messages when notification sounds are disabled"
            enableVibration(true)
            setSound(null, null)
            setShowBadge(true)
        }
        manager.createNotificationChannel(silent)
    }

    private fun thunderSoundUri(): Uri = Uri.parse(
        "${ContentResolver.SCHEME_ANDROID_RESOURCE}://$packageName/${R.raw.zameel_bubble_thunder}",
    )

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private fun value(extras: Bundle, key: String): String =
        extras.get(key)?.toString()?.trim().orEmpty()
}
