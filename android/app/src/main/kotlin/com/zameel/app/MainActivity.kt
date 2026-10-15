package com.zameel.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity

@androidx.annotation.OptIn(markerClass = [androidx.media3.common.util.UnstableApi::class])
class MainActivity : FlutterActivity() {
    private val galleryWriter161 by lazy { GalleryWriter161(this) }
    private var playBilling: ZameelPlayBilling? = null
    override fun onResume() {
        super.onResume()
        ZameelChatVisibility.setForeground(this, true)
    }
    override fun onPause() {
        ZameelChatVisibility.setForeground(this, false)
        super.onPause()
    }
    override fun cleanUpFlutterEngine(engine: io.flutter.embedding.engine.FlutterEngine) {
        playBilling?.close()
        playBilling = null
        super.cleanUpFlutterEngine(engine)
    }
    override fun configureFlutterEngine(engine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(engine)
        DeviceTrust160.register(this, engine.dartExecutor.binaryMessenger)
        SharePreview157.register(this, engine.dartExecutor.binaryMessenger)
        io.flutter.plugin.common.MethodChannel(engine.dartExecutor.binaryMessenger, "zameel/uploads156").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start" -> { val intent = Intent(this, ZameelUploadService156::class.java); if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent); result.success(null) }
                    "stop" -> { stopService(Intent(this, ZameelUploadService156::class.java)); result.success(null) }
                    "failed" -> { ZameelUploadService156.failed(this, call.argument<String>("id") ?: "upload"); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) { result.error("upload_service_unavailable", error.javaClass.simpleName, null) }
        }

        io.flutter.plugin.common.MethodChannel(engine.dartExecutor.binaryMessenger, "zameel/chat_visibility")
            .setMethodCallHandler { call, result ->
                if (call.method != "set") result.notImplemented()
                else {
                    ZameelChatVisibility.set(this, call.argument<String>("conversationId"), call.argument<String>("userId"))
                    result.success(null)
                }
            }

        io.flutter.plugin.common.MethodChannel(engine.dartExecutor.binaryMessenger, "zameel/notification_settings")
            .setMethodCallHandler { call, result ->
                if (call.method != "open") result.notImplemented()
                else try {
                    val intent = if (Build.VERSION.SDK_INT >= 26) Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                    startActivity(intent)
                    result.success(null)
                } catch (e: Exception) { result.error("settings_unavailable", "Notification settings unavailable", null) }
            }
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
    fun saveToGallery161(file: java.io.File, mime: String, name: String,
        result: io.flutter.plugin.common.MethodChannel.Result, done: () -> Unit) {
        galleryWriter161.save(file, mime, name, result, done)
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        galleryWriter161.permission(requestCode, grantResults)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        prepareDecline(intent)
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        prepareDecline(intent)
    }
    private fun prepareDecline(intent: Intent?) {
        if (Build.VERSION.SDK_INT >= 27 && intent?.data?.host == "call" &&
            intent.data?.getQueryParameter("action") == "decline") setShowWhenLocked(true)
    }


    companion object {
        @Volatile
        var isVisible: Boolean = false
            private set
    }

    override fun onStart() {
        super.onStart()
        isVisible = true

    }


    override fun onStop() {
        isVisible = false
        super.onStop()
    }


}
