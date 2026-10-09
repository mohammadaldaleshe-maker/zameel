package com.zameel.app

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
