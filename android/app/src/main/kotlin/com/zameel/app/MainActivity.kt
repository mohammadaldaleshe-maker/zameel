package com.zameel.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val BUBBLE_CHANNEL = "com.zameel.app/bubble_overlay"
        private const val PREFS = "zameel_native_prefs"
        private const val PROMPTED = "overlay_permission_prompted"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BUBBLE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ensureEnabled" -> {
                        val enabled = ensureBubbleOverlayEnabled()
                        result.success(enabled)
                    }
                    "isEnabled" -> result.success(canDrawOverlay() && ZameelBubbleService.isRunning())
                    "disable" -> {
                        stopService(Intent(this, ZameelBubbleService::class.java))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onResume() {
        super.onResume()
        if (canDrawOverlay()) startBubbleService()
    }

    private fun ensureBubbleOverlayEnabled(): Boolean {
        if (canDrawOverlay()) {
            startBubbleService()
            return true
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            startBubbleService()
            return true
        }

        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        if (!prefs.getBoolean(PROMPTED, false)) {
            prefs.edit().putBoolean(PROMPTED, true).apply()
            Toast.makeText(
                this,
                "Enable 'Display over other apps' so Zameel chat bubbles can appear.",
                Toast.LENGTH_LONG,
            ).show()
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName"),
            )
            startActivity(intent)
        }
        return false
    }

    private fun canDrawOverlay(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)

    private fun startBubbleService() {
        if (!canDrawOverlay()) return
        val intent = Intent(this, ZameelBubbleService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
}
