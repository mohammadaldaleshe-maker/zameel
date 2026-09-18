package com.zameel.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import kotlin.math.abs

/**
 * True floating chat head for Zameel direct messages.
 *
 * The service is started only from the foreground after the user grants the
 * Android "display over other apps" permission. Incoming FCM messages merely
 * update the already-running service, so Android 15+ background-start limits
 * do not need to be bypassed.
 */
class ZameelBubbleService : Service() {
    companion object {
        private const val SERVICE_CHANNEL = "zameel_overlay_service_v1"
        private const val SERVICE_NOTIFICATION_ID = 660067
        private const val ACTION_STOP = "com.zameel.app.BUBBLE_STOP"

        @Volatile
        private var activeInstance: ZameelBubbleService? = null

        fun updateFromMessage(
            conversationId: String,
            partnerId: String,
            partnerName: String,
            preview: String,
        ) {
            activeInstance?.showMessageBubble(
                conversationId = conversationId,
                partnerId = partnerId,
                partnerName = partnerName,
                preview = preview,
            )
        }

        fun isRunning(): Boolean = activeInstance != null
    }

    private lateinit var windowManager: WindowManager
    private var bubbleView: TextView? = null
    private var params: WindowManager.LayoutParams? = null
    private var conversationId: String = ""
    private var partnerId: String = ""
    private var partnerName: String = "Zameel"

    override fun onCreate() {
        super.onCreate()
        activeInstance = this
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        createServiceChannel()
        val notification = buildServiceNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                SERVICE_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(SERVICE_NOTIFICATION_ID, notification)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            removeBubble()
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    override fun onDestroy() {
        removeBubble()
        if (activeInstance === this) activeInstance = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    @Suppress("DEPRECATION")
    private fun showMessageBubble(
        conversationId: String,
        partnerId: String,
        partnerName: String,
        preview: String,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            return
        }

        this.conversationId = conversationId
        this.partnerId = partnerId
        this.partnerName = partnerName.ifBlank { "Zameel" }

        val current = bubbleView
        if (current != null) {
            current.text = initials(this.partnerName)
            current.contentDescription = if (preview.isBlank()) this.partnerName else "${this.partnerName}: $preview"
            return
        }

        val density = resources.displayMetrics.density
        val size = (64 * density).toInt()
        val margin = (16 * density).toInt()

        val view = TextView(this).apply {
            text = initials(this@ZameelBubbleService.partnerName)
            gravity = Gravity.CENTER
            textSize = 19f
            setTextColor(0xFFFFFFFF.toInt())
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            elevation = 12 * density
            contentDescription = if (preview.isBlank()) this@ZameelBubbleService.partnerName else "${this@ZameelBubbleService.partnerName}: $preview"
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(0xFF3152E8.toInt())
                setStroke((2 * density).toInt(), 0xFFFFFFFF.toInt())
            }
        }

        val layoutParams = WindowManager.LayoutParams(
            size,
            size,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = margin
            y = (140 * density).toInt()
        }

        var startX = 0
        var startY = 0
        var touchX = 0f
        var touchY = 0f
        var moved = false

        view.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    startX = layoutParams.x
                    startY = layoutParams.y
                    touchX = event.rawX
                    touchY = event.rawY
                    moved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - touchX).toInt()
                    val dy = (event.rawY - touchY).toInt()
                    if (abs(dx) > 8 || abs(dy) > 8) moved = true
                    // END gravity reverses the horizontal coordinate.
                    layoutParams.x = startX - dx
                    layoutParams.y = startY + dy
                    try {
                        windowManager.updateViewLayout(view, layoutParams)
                    } catch (_: Throwable) {}
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!moved) openConversation()
                    true
                }
                else -> false
            }
        }

        try {
            windowManager.addView(view, layoutParams)
            bubbleView = view
            params = layoutParams
        } catch (_: Throwable) {
            bubbleView = null
            params = null
        }
    }

    private fun openConversation() {
        val id = conversationId
        if (id.isBlank()) return
        val deepLink = Uri.Builder()
            .scheme("zameel")
            .authority("chat")
            .appendQueryParameter("conversation_id", id)
            .appendQueryParameter("partner_id", partnerId)
            .appendQueryParameter("partner_name", partnerName)
            .build()
        val intent = Intent(Intent.ACTION_VIEW, deepLink, this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        try {
            startActivity(intent)
        } catch (_: Throwable) {}
    }

    private fun removeBubble() {
        val view = bubbleView ?: return
        try {
            windowManager.removeView(view)
        } catch (_: Throwable) {}
        bubbleView = null
        params = null
    }

    private fun createServiceChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        manager.createNotificationChannel(
            NotificationChannel(
                SERVICE_CHANNEL,
                "Zameel floating chat bubble",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Keeps the Zameel floating message bubble available"
                setShowBadge(false)
            },
        )
    }

    private fun buildServiceNotification(): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val openPending = PendingIntent.getActivity(
            this,
            SERVICE_NOTIFICATION_ID,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stopIntent = Intent(this, ZameelBubbleService::class.java).apply { action = ACTION_STOP }
        val stopPending = PendingIntent.getService(
            this,
            SERVICE_NOTIFICATION_ID + 1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, SERVICE_CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Zameel")
            .setContentText("Floating chat bubble is active")
            .setContentIntent(openPending)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .addAction(0, "Stop bubble", stopPending)
            .build()
    }

    private fun initials(name: String): String {
        val parts = name.trim().split(Regex("\\s+")).filter { it.isNotBlank() }
        if (parts.isEmpty()) return "Z"
        val first = parts.first().take(1)
        val second = if (parts.size > 1) parts.last().take(1) else ""
        return (first + second).uppercase()
    }
}
