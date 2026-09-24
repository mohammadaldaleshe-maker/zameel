package com.zameel.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Person
import android.content.ContentResolver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.Icon
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingReceiver
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import kotlin.math.max

/**
 * Zameel's single FCM manifest receiver.
 *
 * It subclasses FlutterFire's own receiver and always delegates to super so
 * existing FirebaseMessaging foreground/background behavior is preserved.
 * Direct-chat data messages are additionally rendered as official Android
 * Conversation/Bubble notifications.
 */
class ZameelBubbleReceiver : FlutterFirebaseMessagingReceiver() {
    companion object {
        private const val TAG = "ZameelBubble"
        // v2 intentionally creates fresh Android channels. Bubble capability
        // is effectively sticky once a channel exists on many OEM builds.
        private const val CHAT_CHANNEL = "zameel_chat_bubbles_v2"
        private const val CHAT_SILENT_CHANNEL = "zameel_chat_bubbles_silent_v2"
        private const val PRIMARY = 0xFF3152E8.toInt()
        private const val SECONDARY = 0xFF4B23B7.toInt()
        private const val ACCENT = 0xFF27C7C7.toInt()
        private val avatarExecutor = Executors.newSingleThreadExecutor()
    }

    override fun onReceive(context: Context, intent: Intent) {
        val appContext = context.applicationContext
        val extras = intent.extras

        if (extras != null && isDirectMessage(extras)) {
            val bubbleEnabled = value(extras, "bubble_enabled").lowercase() != "false"
            val overlayAllowed = bubbleEnabled && ZameelOverlayService.canDrawOverlays(appContext)
            val appInForeground = MainActivity.isVisible

            // Prefer a real app-over-app chat head when Zameel is behind another
            // app and the user granted overlay access. If Android rejects the
            // foreground-service start for any reason, immediately fall back to
            // the official Conversation/Bubble notification path.
            if (overlayAllowed && !appInForeground) {
                // The host service is started while MainActivity is visible and
                // remains foreground. The FCM receiver only sends an in-process
                // bubble command; it never tries to create a foreground service
                // from the background. This is reliable on Android 12-16 even
                // when FCM downgrades a nominally high-priority delivery.
                val deliveredToHost = ZameelOverlayService.showFromPush(appContext, extras)
                if (!deliveredToHost) {
                    postConversationFallback(appContext, extras)
                }
            } else {
                postConversationFallback(appContext, extras)
            }
        }

        // Preserve FlutterFire's existing onMessage/background-isolate path for
        // every push type, including direct messages and calls.
        super.onReceive(context, intent)
    }

    internal fun postConversationFallback(context: Context, extras: Bundle) {
        try {
            showConversationNotification(context, extras, avatarSource = null)

            val avatarUrl = value(extras, "sender_avatar").takeUnless {
                it.isBlank() || it.equals("null", ignoreCase = true)
            }
            if (avatarUrl != null) {
                val copied = Bundle(extras)
                avatarExecutor.execute {
                    val avatar = loadAvatar(avatarUrl)
                    if (avatar != null) {
                        try {
                            showConversationNotification(context, copied, avatar)
                        } catch (error: Throwable) {
                            Log.w(TAG, "Could not refresh bubble avatar", error)
                        }
                    }
                }
            }
        } catch (error: Throwable) {
            Log.w(TAG, "Could not post conversation notification", error)
        }
    }


    private fun isDirectMessage(extras: Bundle): Boolean {
        val type = value(extras, "type").ifBlank { value(extras, "notification_type") }
        return type == "message" && value(extras, "conversation_id").isNotBlank()
    }

    private fun showConversationNotification(
        context: Context,
        extras: Bundle,
        avatarSource: Bitmap?,
    ) {
        val conversationId = value(extras, "conversation_id")
        if (conversationId.isBlank()) return

        val senderId = value(extras, "sender_id").ifBlank { "zameel-colleague" }
        val senderName = value(extras, "sender_name").ifBlank { "Zameel" }
        val preview = value(extras, "message_preview")
            .ifBlank { value(extras, "body") }
            .ifBlank { "New message" }
        val playSound = value(extras, "play_sound").lowercase() != "false"
        val bubbleEnabled = value(extras, "bubble_enabled").lowercase() != "false"

        ensureChannels(context)

        val bubbleBitmap = buildBubbleBitmap(avatarSource, senderName)
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val notificationId = stableId(conversationId)
        val shortcutId = "zameel-chat-$conversationId"
        val deepLink = Uri.Builder()
            .scheme("zameel")
            .authority("chat")
            .appendQueryParameter("conversation_id", conversationId)
            .appendQueryParameter("partner_id", senderId)
            .appendQueryParameter("partner_name", senderName)
            .build()

        val contentIntent = Intent(Intent.ACTION_VIEW, deepLink, context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val contentPendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val channelId = if (playSound) CHAT_CHANNEL else CHAT_SILENT_CHANNEL
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(senderName)
            .setContentText(preview)
            .setContentIntent(contentPendingIntent)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setColor(PRIMARY)
            .setLargeIcon(bubbleBitmap)
            .setWhen(System.currentTimeMillis())
            .setShowWhen(true)

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            builder.setPriority(Notification.PRIORITY_HIGH)
            if (playSound) builder.setSound(thunderSoundUri(context))
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val bubbleIcon = Icon.createWithAdaptiveBitmap(bubbleBitmap)
            val person = Person.Builder()
                .setName(senderName)
                .setKey(senderId)
                .setIcon(bubbleIcon)
                .setImportant(true)
                .build()

            val style = Notification.MessagingStyle(person)
                .addMessage(preview, System.currentTimeMillis(), person)
            builder.setStyle(style)
            builder.addPerson(person)

            var shortcutReady = false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                shortcutReady = publishConversationShortcut(
                    context = context,
                    shortcutId = shortcutId,
                    senderName = senderName,
                    person = person,
                    bubbleIcon = bubbleIcon,
                    deepLink = deepLink,
                )
                if (shortcutReady) builder.setShortcutId(shortcutId)
            }

            // Android 11+ requires the valid long-lived conversation shortcut.
            // Android 10 can bubble without that Android-11 requirement.
            if (bubbleEnabled && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                (Build.VERSION.SDK_INT < Build.VERSION_CODES.R || shortcutReady)
            ) {
                val bubbleBuilder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    // Android 11+ bubbles are conversation-shortcut based. Using
                    // the shortcut constructor avoids PendingIntent mutability
                    // ambiguity and lets the system manage the bubble activity.
                    Notification.BubbleMetadata.Builder(shortcutId)
                } else {
                    // Android 10 requires a PendingIntent-based bubble. Leave the
                    // PendingIntent mutable-by-default on pre-Android 12; newer
                    // versions use the shortcut constructor above.
                    val bubbleIntent = Intent(
                        Intent.ACTION_VIEW,
                        deepLink,
                        context,
                        ZameelBubbleActivity::class.java,
                    ).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_DOCUMENT or Intent.FLAG_ACTIVITY_MULTIPLE_TASK
                    }
                    val bubblePendingIntent = PendingIntent.getActivity(
                        context,
                        notificationId xor 0x5A5A,
                        bubbleIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT,
                    )
                    @Suppress("DEPRECATION")
                    Notification.BubbleMetadata.Builder()
                        .setIntent(bubblePendingIntent)
                        .setIcon(bubbleIcon)
                }
                // Incoming background messages should appear collapsed. Android
                // owns whether a conversation is permitted to bubble; auto-expand
                // is intentionally not requested because it is ignored in the
                // background and is user-disruptive.
                bubbleBuilder.setDesiredHeight(720)
                builder.setBubbleMetadata(bubbleBuilder.build())
            }
        }

        notificationManager.notify(notificationId, builder.build())
        Log.d(TAG, "Conversation notification posted for $conversationId")
    }

    private fun publishConversationShortcut(
        context: Context,
        shortcutId: String,
        senderName: String,
        person: Person,
        bubbleIcon: Icon,
        deepLink: Uri,
    ): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false
        return try {
            val shortcutManager = context.getSystemService(ShortcutManager::class.java) ?: return false
            val shortcutIntent = Intent(Intent.ACTION_VIEW, deepLink, context, MainActivity::class.java)
            val shortcut = ShortcutInfo.Builder(context, shortcutId)
                .setShortLabel(senderName.take(30))
                .setLongLabel(senderName.take(60))
                .setIcon(bubbleIcon)
                .setIntent(shortcutIntent)
                .setActivity(ComponentName(context, MainActivity::class.java))
                .setCategories(setOf("com.zameel.app.category.CHAT"))
                .setPersons(arrayOf(person))
                .setLongLived(true)
                .build()
            // Android 11+ pushDynamicShortcut keeps the newest conversation
            // available and automatically evicts an older dynamic shortcut when
            // the per-activity limit is reached. The platform method returns Unit;
            // reaching this line without an exception means the shortcut was pushed.
            shortcutManager.pushDynamicShortcut(shortcut)
            true
        } catch (error: Throwable) {
            // Still show a normal conversation notification if the OS rejects
            // or rate-limits a shortcut; never lose the message notification.
            Log.w(TAG, "Could not publish conversation shortcut", error)
            false
        }
    }

    private fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_COMMUNICATION_INSTANT)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val chat = NotificationChannel(
            CHAT_CHANNEL,
            "Zameel chat bubbles",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Direct Zameel messages and conversation bubbles"
            enableVibration(true)
            setSound(thunderSoundUri(context), attributes)
            setShowBadge(true)
            if (Build.VERSION.SDK_INT == Build.VERSION_CODES.Q) {
                setAllowBubbles(true)
            }
        }
        manager.createNotificationChannel(chat)

        val silent = NotificationChannel(
            CHAT_SILENT_CHANNEL,
            "Zameel chat bubbles (silent)",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Direct Zameel messages when notification sounds are disabled"
            enableVibration(true)
            setSound(null, null)
            setShowBadge(true)
            if (Build.VERSION.SDK_INT == Build.VERSION_CODES.Q) {
                setAllowBubbles(true)
            }
        }
        manager.createNotificationChannel(silent)
    }

    private fun thunderSoundUri(context: Context): Uri = Uri.parse(
        "${ContentResolver.SCHEME_ANDROID_RESOURCE}://${context.packageName}/${R.raw.zameel_bubble_thunder}",
    )

    private fun stableId(value: String): Int = value.hashCode() and 0x7fffffff

    private fun value(extras: Bundle, key: String): String =
        extras.get(key)?.toString()?.trim().orEmpty()

    private fun loadAvatar(url: String?): Bitmap? {
        if (url.isNullOrBlank() || (!url.startsWith("https://") && !url.startsWith("http://"))) {
            return null
        }
        var connection: HttpURLConnection? = null
        return try {
            connection = URL(url).openConnection() as HttpURLConnection
            connection.connectTimeout = 2200
            connection.readTimeout = 3200
            connection.instanceFollowRedirects = true
            connection.doInput = true
            connection.connect()
            if (connection.responseCode !in 200..299) return null
            val length = connection.contentLengthLong
            if (length > 2_000_000L) return null
            connection.inputStream.use { BitmapFactory.decodeStream(it) }
        } catch (_: Throwable) {
            null
        } finally {
            connection?.disconnect()
        }
    }

    private fun buildBubbleBitmap(source: Bitmap?, senderName: String): Bitmap {
        val size = 256
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        paint.color = PRIMARY
        canvas.drawCircle(128f, 128f, 124f, paint)

        canvas.save()
        val avatarPath = Path().apply { addCircle(128f, 128f, 111f, Path.Direction.CW) }
        canvas.clipPath(avatarPath)
        if (source != null) {
            val srcW = source.width.toFloat()
            val srcH = source.height.toFloat()
            val scale = max(222f / srcW, 222f / srcH)
            val dx = 128f - (srcW * scale) / 2f
            val dy = 128f - (srcH * scale) / 2f
            val matrix = Matrix().apply {
                setScale(scale, scale)
                postTranslate(dx, dy)
            }
            canvas.drawBitmap(source, matrix, paint)
        } else {
            paint.color = SECONDARY
            canvas.drawRect(RectF(17f, 17f, 239f, 239f), paint)
            paint.color = Color.WHITE
            paint.textAlign = Paint.Align.CENTER
            paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            paint.textSize = 92f
            val initial = senderName.trim().firstOrNull()?.uppercaseChar()?.toString() ?: "Z"
            canvas.drawText(initial, 128f, 159f, paint)
        }
        canvas.restore()

        paint.style = Paint.Style.FILL
        paint.color = Color.WHITE
        canvas.drawCircle(201f, 201f, 51f, paint)
        paint.color = SECONDARY
        canvas.drawCircle(201f, 201f, 45f, paint)

        paint.color = Color.WHITE
        paint.textAlign = Paint.Align.CENTER
        paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        paint.textSize = 50f
        canvas.drawText("Z", 197f, 218f, paint)

        val bolt = Path().apply {
            moveTo(207f, 166f)
            lineTo(190f, 199f)
            lineTo(203f, 199f)
            lineTo(193f, 231f)
            lineTo(218f, 192f)
            lineTo(205f, 192f)
            close()
        }
        paint.color = ACCENT
        canvas.drawPath(bolt, paint)
        return bitmap
    }
}
