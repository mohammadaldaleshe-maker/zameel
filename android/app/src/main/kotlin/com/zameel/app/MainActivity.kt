package com.zameel.app

import android.app.AlertDialog
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity

@androidx.annotation.OptIn(markerClass = [androidx.media3.common.util.UnstableApi::class])
class MainActivity : FlutterActivity() {
    private var playBilling: ZameelPlayBilling? = null
    private var pendingExport: Triple<java.io.File, io.flutter.plugin.common.MethodChannel.Result, () -> Unit>? = null
    override fun cleanUpFlutterEngine(engine: io.flutter.embedding.engine.FlutterEngine) {
        playBilling?.close()
        playBilling = null
        super.cleanUpFlutterEngine(engine)
    }
    override fun configureFlutterEngine(engine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(engine)
        playBilling?.close()
        playBilling = ZameelPlayBilling(this, engine)
        io.flutter.plugin.common.MethodChannel(engine.dartExecutor.binaryMessenger, "zameel/incoming_calls")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setUser" -> {
                        ZameelIncomingCall.setUser(this, call.argument<String>("userId"))
                        result.success(null)
                    }
                    "dismiss" -> {
                        ZameelIncomingCall.dismiss(this, call.argument<String>("roomId").orEmpty())
                        result.success(null)
                    }
                    "canFullScreen" -> result.success(Build.VERSION.SDK_INT < 34 ||
                        getSystemService(NotificationManager::class.java)?.canUseFullScreenIntent() == true)
                    "requestFullScreen" -> {
                        if (Build.VERSION.SDK_INT >= 34) startActivity(Intent(
                            Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                            Uri.parse("package:$packageName")))
                        result.success(null)
                    }
                    "finishDecline" -> {
                        result.success(null)
                        if (getSystemService(android.app.KeyguardManager::class.java)?.isKeyguardLocked == true) finish()
                        else if (Build.VERSION.SDK_INT >= 27) setShowWhenLocked(false)
                    }
                    else -> result.notImplemented()
                }
            }
        io.flutter.plugin.common.MethodChannel(engine.dartExecutor.binaryMessenger, "zameel/call_audio")
            .setMethodCallHandler { call, result ->
                if (call.method == "clear") {
                    val audio = getSystemService(android.media.AudioManager::class.java)
                    if (Build.VERSION.SDK_INT >= 31) audio?.clearCommunicationDevice()
                    audio?.mode = android.media.AudioManager.MODE_NORMAL
                    result.success(null)
                } else if (call.method != "setSpeaker") { result.notImplemented() }
                else {
                    val speaker = call.argument<Boolean>("enabled") == true
                    try {
                        val audio = getSystemService(android.media.AudioManager::class.java)
                            ?: throw IllegalStateException("Audio service unavailable")
                        audio.mode = android.media.AudioManager.MODE_IN_COMMUNICATION
                        if (Build.VERSION.SDK_INT >= 31) {
                            val type = if (speaker) android.media.AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
                                else android.media.AudioDeviceInfo.TYPE_BUILTIN_EARPIECE
                            val device = audio.availableCommunicationDevices.firstOrNull { it.type == type }
                            if (device == null) result.error("route_unavailable", "Audio output unavailable", null)
                            else result.success(audio.setCommunicationDevice(device))
                        } else {
                            @Suppress("DEPRECATION")
                            audio.isSpeakerphoneOn = speaker
                            result.success(true)
                        }
                    } catch (error: Exception) { result.error("audio_route_failed", error.message, null) }
                }
            }
        val exporter = WatermarkedMediaExporter(this)
        val mediaMaintenance = ZameelMediaMaintenance(this)
        io.flutter.plugin.common.MethodChannel(engine.dartExecutor.binaryMessenger, "zameel/media_export")
            .setMethodCallHandler { call, result ->
                if (call.method == "export") exporter.export(call.argument<String>("path") ?: "",
                    call.argument<Boolean>("video") == true, call.argument<String>("owner") ?: "زميل", result)
                else when(call.method) {
                    "saveOriginal" -> mediaMaintenance.save(call.argument<String>("path") ?: "", call.argument<String>("type") ?: "", result)
                    "cacheStoryAudio" -> mediaMaintenance.cacheAudio(call.argument<ByteArray>("bytes") ?: byteArrayOf(), result)
                    "composeStory" -> mediaMaintenance.compose(call.argument<String>("path") ?: "", call.argument<String>("audio") ?: "",
                        call.argument<Boolean>("image") == true, (call.argument<Number>("startMs") ?: 0).toLong(),
                        (call.argument<Number>("durationMs") ?: 15000).toLong(),
                        (call.argument<Number>("audioVolume") ?: 1.0).toFloat(),
                        (call.argument<Number>("originalVolume") ?: 0.0).toFloat(), result)
                    else -> result.notImplemented()
                }
            }
    }
    fun saveExportWithPicker(file: java.io.File, mime: String, name: String,
        result: io.flutter.plugin.common.MethodChannel.Result, done: () -> Unit) {
        pendingExport = Triple(file, result, done)
        try {
            startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE); type = mime; putExtra(Intent.EXTRA_TITLE, name)
            }, 138)
        } catch (e: Exception) {
            pendingExport = null; file.delete(); done(); result.error("save_unavailable", e.message, null)
        }
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if(requestCode != 138) return
        val pending = pendingExport ?: return
        pendingExport = null
        val uri = data?.data
        if(resultCode != RESULT_OK || uri == null) {
            pending.first.delete(); pending.third(); pending.second.error("cancelled", "تم إلغاء الحفظ", null); return
        }
        Thread {
            try {
                contentResolver.openOutputStream(uri)!!.use { out -> pending.first.inputStream().use { it.copyTo(out) } }
                runOnUiThread { pending.second.success(uri.toString()) }
            } catch(e: Exception) { runOnUiThread { pending.second.error("save_failed", e.message, null) } }
            finally { pending.first.delete(); runOnUiThread { pending.third() } }
        }.start()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        prepareDecline(intent)
        maybeAskForOverlayPermission()
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        prepareDecline(intent)
    }
    private fun prepareDecline(intent: Intent?) {
        if (Build.VERSION.SDK_INT >= 27 && intent?.data?.host == "call" &&
            intent.data?.getQueryParameter("action") == "decline") setShowWhenLocked(true)
    }

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
