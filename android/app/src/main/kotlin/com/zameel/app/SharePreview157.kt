package com.zameel.app

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

object SharePreview157 {
    fun register(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, "zameel/share_preview157").setMethodCallHandler { call, result ->
            if (call.method != "videoCover") { result.notImplemented(); return@setMethodCallHandler }
            val path = call.argument<String>("path")
            if (path.isNullOrBlank() || !File(path).isFile) { result.success(null); return@setMethodCallHandler }
            Thread {
                var output: String? = null
                val retriever = MediaMetadataRetriever()
                try {
                    retriever.setDataSource(path)
                    val frame = retriever.getFrameAtTime(1_000_000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                        ?: retriever.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                    if (frame != null) {
                        val scale = minOf(1.0, 720.0 / maxOf(frame.width, frame.height))
                        val image = Bitmap.createScaledBitmap(frame, maxOf(1, (frame.width * scale).toInt()), maxOf(1, (frame.height * scale).toInt()), true)
                        val file = File.createTempFile("share157_", ".jpg", context.cacheDir)
                        file.outputStream().use { image.compress(Bitmap.CompressFormat.JPEG, 85, it) }
                        if (image !== frame) image.recycle()
                        frame.recycle()
                        output = file.absolutePath
                    }
                } catch (_: Exception) { /* Publishing continues if this format has no extractable frame. */ }
                finally { try { retriever.release() } catch (_: Exception) {} }
                Handler(Looper.getMainLooper()).post { result.success(output) }
            }.start()
        }
    }
}
