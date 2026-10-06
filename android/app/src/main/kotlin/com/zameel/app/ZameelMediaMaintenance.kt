package com.zameel.app

import android.content.ContentValues
import android.net.Uri
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.audio.ChannelMixingAudioProcessor
import androidx.media3.common.audio.ChannelMixingMatrix
import androidx.media3.common.util.UnstableApi
import androidx.media3.transformer.*
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

@UnstableApi
class ZameelMediaMaintenance(private val activity: MainActivity) {
    private val worker = Executors.newSingleThreadExecutor()
    private var transformer: Transformer? = null
    fun save(path: String, type: String, result: MethodChannel.Result) {
        if (type !in setOf("image", "video", "audio")) { result.error("invalid_type", null, null); return }
        worker.execute {
            var target: Uri? = null
            try {
                val source = File(path)
                require(source.isFile)
                val detectedMime = if (type == "image") source.inputStream().use { stream ->
                    val header = ByteArray(12); stream.read(header)
                    when { header[0] == 0x89.toByte() && header[1] == 0x50.toByte() -> "image/png"
                        String(header, 0, 3) == "GIF" -> "image/gif"
                        String(header, 8, 4) == "WEBP" -> "image/webp"
                        else -> "image/jpeg" }
                } else {
                    val retriever = MediaMetadataRetriever()
                    try { retriever.setDataSource(path); retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE) }
                    finally { retriever.release() }
                }
                val fallbackExtension = when(type) { "image" -> "jpg"; "video" -> "mp4"; else -> "m4a" }
                val extension = when(detectedMime) { "image/png" -> "png"; "image/gif" -> "gif"; "image/webp" -> "webp"; "audio/mpeg" -> "mp3"; "audio/ogg" -> "ogg"; "audio/wav" -> "wav"; "video/webm" -> "webm"; else -> fallbackExtension }
                val mime = detectedMime ?: when(type) { "image" -> "image/jpeg"; "video" -> "video/mp4"; else -> "audio/mp4" }
                val name = "Zameel_${System.currentTimeMillis()}.$extension"
                if (Build.VERSION.SDK_INT >= 29) {
                    val collection = when(type) {
                        "image" -> MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                        "video" -> MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                        else -> MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
                    }
                    val folder = when(type) { "image" -> Environment.DIRECTORY_PICTURES; "video" -> Environment.DIRECTORY_MOVIES; else -> Environment.DIRECTORY_MUSIC }
                    val values = ContentValues().apply {
                        put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                        put(MediaStore.MediaColumns.MIME_TYPE, mime)
                        put(MediaStore.MediaColumns.RELATIVE_PATH, "$folder/Zameel")
                        put(MediaStore.MediaColumns.IS_PENDING, 1)
                    }
                    val uri = activity.contentResolver.insert(collection, values) ?: error("save_failed")
                    target = uri
                    activity.contentResolver.openOutputStream(uri).use { out -> requireNotNull(out); source.inputStream().use { it.copyTo(out) } }
                    values.clear(); values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                    activity.contentResolver.update(uri, values, null, null)
                    activity.runOnUiThread { result.success(uri.toString()) }
                } else activity.runOnUiThread { activity.saveExportWithPicker(source, mime, name, result) {} }
            } catch (error: Exception) {
                target?.let { activity.contentResolver.delete(it, null, null) }
                activity.runOnUiThread { result.error("save_failed", error.message, null) }
            }
        }
    }
    fun cacheAudio(bytes: ByteArray, result: MethodChannel.Result) {
        worker.execute {
            try {
                require(bytes.isNotEmpty() && bytes.size <= 30 * 1024 * 1024)
                val output = File(activity.cacheDir, "story_audio_${System.nanoTime()}")
                output.writeBytes(bytes)
                activity.runOnUiThread { result.success(output.path) }
            } catch (e: Exception) { activity.runOnUiThread { result.error("audio_failed", e.message, null) } }
        }
    }
    private fun volume(value: Float): ChannelMixingAudioProcessor = ChannelMixingAudioProcessor().apply {
        for (channels in 1..8) putChannelMixingMatrix(ChannelMixingMatrix.create(channels, channels).scaleBy(value.coerceIn(0f, 1f)))
    }
    fun compose(path: String, audio: String, image: Boolean, start: Long, duration: Long,
                audioVolume: Float, originalVolume: Float, result: MethodChannel.Result) {
        if (transformer != null) { result.error("busy", null, null); return }
        val output = File(activity.cacheDir, "story_mix_${System.nanoTime()}.mp4")
        try {
            require(File(path).isFile && File(audio).isFile && start >= 0 && duration in 1000..45000)
            val visualMedia = MediaItem.Builder().setUri(Uri.fromFile(File(path)))
            if (image) visualMedia.setImageDurationMs(duration)
            else visualMedia.setClippingConfiguration(MediaItem.ClippingConfiguration.Builder().setEndPositionMs(duration).build())
            val visual = EditedMediaItem.Builder(visualMedia.build())
                .setRemoveAudio(image || originalVolume <= 0f)
                .setEffects(Effects(listOf<androidx.media3.common.audio.AudioProcessor>(volume(originalVolume)), emptyList()))
            if (image) visual.setDurationUs(duration * 1000).setFrameRate(30)
            val sound = EditedMediaItem.Builder(MediaItem.Builder().setUri(Uri.fromFile(File(audio)))
                .setClippingConfiguration(MediaItem.ClippingConfiguration.Builder().setStartPositionMs(start).setEndPositionMs(start + duration).build()).build())
                .setRemoveVideo(true).setEffects(Effects(listOf<androidx.media3.common.audio.AudioProcessor>(volume(audioVolume)), emptyList())).build()
            val composition = Composition.Builder(listOf(
                EditedMediaItemSequence.Builder(visual.build()).build(),
                EditedMediaItemSequence.Builder(sound).build())).build()
            transformer = Transformer.Builder(activity)
                .setVideoMimeType(MimeTypes.VIDEO_H264).setAudioMimeType(MimeTypes.AUDIO_AAC)
                .addListener(object: Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        transformer = null; result.success(output.path)
                    }
                    override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) {
                        transformer = null; output.delete(); result.error("compose_failed", exportException.message, null)
                    }
                }).build()
            transformer!!.start(composition, output.path)
        } catch (e: Exception) { transformer = null; output.delete(); result.error("compose_failed", e.message, null) }
    }
}
