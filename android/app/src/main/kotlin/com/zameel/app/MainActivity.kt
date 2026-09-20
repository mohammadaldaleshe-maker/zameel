package com.zameel.app

import android.app.AlertDialog
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private var overlayPromptedThisProcess = false
    private var systemBubblePromptedThisProcess = false

    companion object {
        @Volatile
        var isVisible: Boolean = false
            private set
    }

    override fun onStart() {
        super.onStart()
        isVisible = true

        // Never keep a permanent foreground bubble host while Zameel is open.
        // If a message-created overlay service is still alive, hide its chat
        // head and stop only that short-lived service. The actual message
        // notification remains available until the user opens or dismisses it.
        ZameelOverlayService.hideBubbleAndStop(this, keepMessageNotification = true)
    }

    override fun onResume() {
        super.onResume()
        // Overlay permission is used only when a real incoming message arrives.
        // No service and no test bubble are started merely because Zameel opens.
    }

    override fun onStop() {
        isVisible = false
        super.onStop()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        maybeAskForOverlayPermission()
    }

    /**
     * A real app-over-app chat head needs Android's explicit overlay permission.
     * Ask at most once per app process. If the user chooses "Not now", a later
     * app launch can ask again; if Android permission is ever revoked, the flow
     * is recoverable without clearing app data. Declining never blocks the rest
     * of Zameel because the native Android conversation notification remains the
     * fallback.
     */
    private fun maybeAskForOverlayPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        if (Settings.canDrawOverlays(this)) return

        if (overlayPromptedThisProcess) return
        overlayPromptedThisProcess = true

        window.decorView.post {
            if (isFinishing || isDestroyed || Settings.canDrawOverlays(this)) return@post
            val language = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                resources.configuration.locales[0].language
            } else {
                @Suppress("DEPRECATION")
                resources.configuration.locale.language
            }
            val arabic = language == "ar"
            AlertDialog.Builder(this)
                .setTitle(if (arabic) "فقاعة Zameel العائمة" else "Zameel floating bubble")
                .setMessage(
                    if (arabic) {
                        "لإظهار فقاعة رسائل Zameel فوق التطبيقات الأخرى، افتح إعداد الظهور فوق التطبيقات. إذا ظهرت قائمة التطبيقات فاختر Zameel ثم فعّل السماح. بعد الرجوع إلى Zameel لا يظهر أي إشعار دائم؛ ستظهر الفقاعة وإشعار الرسالة فقط عند وصول رسالة جديدة. إذا لم تفعّله ستبقى إشعارات الدردشة العادية تعمل."
                    } else {
                        "To show Zameel chat heads over other apps, open the display-over-apps setting. If Android shows an app list, choose Zameel and enable permission. When you return to Zameel there is no permanent bubble-service notification; the bubble and message alert appear only when a new message arrives. If you decline, normal chat notifications will continue to work."
                    },
                )
                .setNegativeButton(if (arabic) "ليس الآن" else "Not now") { _, _ ->
                    maybeOfferSystemBubbleSettings()
                }
                .setPositiveButton(if (arabic) "تفعيل" else "Enable") { _, _ ->
                    try {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName"),
                            ),
                        )
                    } catch (_: Throwable) {
                        startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION))
                    }
                }
                .show()
        }
    }

    /**
     * Android 11+ does not let an app force system bubbles. If the custom
     * overlay is unavailable, offer the official app bubble settings instead of
     * pretending setAllowBubbles(true) can override the user's choice.
     */
    private fun maybeOfferSystemBubbleSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        if (systemBubblePromptedThisProcess) return

        val manager = getSystemService(NotificationManager::class.java) ?: return
        val bubblesAlreadyAllowed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            manager.areBubblesEnabled() &&
                manager.bubblePreference != NotificationManager.BUBBLE_PREFERENCE_NONE
        } else {
            @Suppress("DEPRECATION")
            manager.areBubblesAllowed()
        }
        val channelAllowsBubbles = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val channels = listOfNotNull(
                manager.getNotificationChannel("zameel_chat_bubbles_v2"),
                manager.getNotificationChannel("zameel_chat_bubbles_silent_v2"),
            )
            // Before the channels exist there is nothing useful to inspect. Once
            // either channel exists, require every Zameel direct-message channel
            // to be permitted to bubble instead of checking only the app-wide switch.
            channels.isEmpty() || channels.all { it.canBubble() }
        } else {
            true
        }
        if (bubblesAlreadyAllowed && channelAllowsBubbles) return

        systemBubblePromptedThisProcess = true
        val language = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            resources.configuration.locales[0].language
        } else {
            @Suppress("DEPRECATION")
            resources.configuration.locale.language
        }
        val arabic = language == "ar"

        AlertDialog.Builder(this)
            .setTitle(if (arabic) "تفعيل فقاعات المحادثة" else "Enable chat bubbles")
            .setMessage(
                if (arabic) {
                    "Android يمنع التطبيقات من فرض فقاعات النظام تلقائيًا. فعّل فقاعات Zameel من الإعدادات ليبقى لديك مسار رسمي احتياطي إذا أوقف النظام الفقاعة العائمة."
                } else {
                    "Android does not let apps force system bubbles. Enable Zameel bubbles in settings so there is an official fallback if Android stops the floating overlay."
                },
            )
            .setNegativeButton(if (arabic) "لاحقًا" else "Later", null)
            .setPositiveButton(if (arabic) "فتح الإعدادات" else "Open settings") { _, _ ->
                try {
                    startActivity(
                        Intent(Settings.ACTION_APP_NOTIFICATION_BUBBLE_SETTINGS).apply {
                            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        },
                    )
                } catch (_: Throwable) {
                    try {
                        startActivity(
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            },
                        )
                    } catch (_: Throwable) {
                    }
                }
            }
            .show()
    }

}
