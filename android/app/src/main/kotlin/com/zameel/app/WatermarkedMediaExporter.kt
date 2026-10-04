package com.zameel.app

import android.content.ContentValues
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.OverlayEffect
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import com.google.common.collect.ImmutableList
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

@UnstableApi
class WatermarkedMediaExporter(private val activity: MainActivity) {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var busy = false
    private var transformer: Transformer? = null

    private fun overlay(width: Int, height: Int, owner: String): Bitmap {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val size = (width * .035f).coerceIn(14f, 48f)
        val padding = size * .7f
        val band = size * 2.8f
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.color = Color.argb(155, 0, 0, 0)
        canvas.drawRect(0f, height - band, width.toFloat(), height.toFloat(), paint)
        val logo = activity.assets.open("flutter_assets/assets/branding/zameel_mark_white.png").use {
            BitmapFactory.decodeStream(it)
        }
        val logoSize = (band - padding).toInt()
        canvas.drawBitmap(logo, null, Rect(padding.toInt(), height - logoSize - padding.toInt()/2,
            padding.toInt()+logoSize, height-padding.toInt()/2), null)
        logo.recycle()
        paint.color = Color.WHITE
        paint.textSize = size
        paint.isFakeBoldText = true
        var text = "Zameel • $owner"
        val available = width - logoSize - padding * 3
        while (text.length > 12 && paint.measureText(text) > available) text = text.dropLast(2) + "…"
        canvas.drawText(text, logoSize + padding * 2, height - padding, paint)
        return bitmap
    }

    fun export(path: String, video: Boolean, owner: String, result: MethodChannel.Result) {
        if (busy) { result.error("export_busy", "يوجد تنزيل قيد المعالجة", null); return }
        val source = File(path)
        if (!source.exists() || source.length() == 0L) {
            result.error("missing_media", "تعذر قراءة الوسائط", null); return
        }
        // Flutter supplies an app-owned cache file, never an arbitrary filesystem path.
        if (!source.canonicalPath.startsWith(activity.filesDir.parentFile!!.canonicalPath + File.separator)) {
            result.error("invalid_path", "مسار غير مسموح", null); return
        }
        busy = true
        val output = File(activity.cacheDir, "zameel_export_${System.nanoTime()}.${if(video) "mp4" else "jpg"}")
        fun failure(error: Throwable) {
            output.delete(); busy = false
            result.error("export_failed", error.message ?: "تعذر حفظ الوسائط", null)
        }
        fun save() {
            worker.execute {
                try {
                    val name = "Zameel_${System.currentTimeMillis()}.${if(video) "mp4" else "jpg"}"
                    if (Build.VERSION.SDK_INT >= 29) {
                        val collection = if(video) MediaStore.Video.Media.EXTERNAL_CONTENT_URI else MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                        val values = ContentValues().apply {
                            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                            put(MediaStore.MediaColumns.MIME_TYPE, if(video) "video/mp4" else "image/jpeg")
                            put(MediaStore.MediaColumns.RELATIVE_PATH, if(video) "Movies/Zameel" else "Pictures/Zameel")
                            put(MediaStore.MediaColumns.IS_PENDING, 1)
                        }
                        val uri = activity.contentResolver.insert(collection, values) ?: error("media_store_failed")
                        try {
                            activity.contentResolver.openOutputStream(uri)!!.use { dest -> output.inputStream().use { it.copyTo(dest) } }
                            values.clear(); values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                            activity.contentResolver.update(uri, values, null, null)
                        } catch (e: Throwable) { activity.contentResolver.delete(uri, null, null); throw e }
                        output.delete()
                        main.post { busy = false; result.success(uri.toString()) }
                    } else {
                        main.post { activity.saveExportWithPicker(output, if(video) "video/mp4" else "image/jpeg", name, result) { busy = false } }
                    }
                } catch (e: Throwable) { main.post { failure(e) } }
            }
        }
        if (!video) {
            worker.execute {
                try {
                    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                    BitmapFactory.decodeFile(path, bounds)
                    val opts = BitmapFactory.Options().apply { inSampleSize = 1 }
                    while (bounds.outWidth / opts.inSampleSize > 4096 || bounds.outHeight / opts.inSampleSize > 4096) opts.inSampleSize *= 2
                    val image = BitmapFactory.decodeFile(path, opts) ?: error("invalid_image")
                    val orientation = try { android.media.ExifInterface(path).getAttributeInt(android.media.ExifInterface.TAG_ORIENTATION, android.media.ExifInterface.ORIENTATION_NORMAL) } catch (_: Exception) { android.media.ExifInterface.ORIENTATION_NORMAL }
                    val matrix = android.graphics.Matrix()
                    when (orientation) {
                        android.media.ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
                        android.media.ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
                        android.media.ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
                        android.media.ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
                        android.media.ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
                        android.media.ExifInterface.ORIENTATION_TRANSPOSE -> { matrix.postRotate(90f); matrix.postScale(-1f, 1f) }
                        android.media.ExifInterface.ORIENTATION_TRANSVERSE -> { matrix.postRotate(270f); matrix.postScale(-1f, 1f) }
                    }
                    val oriented = Bitmap.createBitmap(image, 0, 0, image.width, image.height, matrix, true)
                    val merged = oriented.copy(Bitmap.Config.ARGB_8888, true) ?: error("image_copy_failed")
                    val watermark = overlay(merged.width, merged.height, owner)
                    Canvas(merged).drawBitmap(watermark, 0f, 0f, null)
                    output.outputStream().use { merged.compress(Bitmap.CompressFormat.JPEG, 95, it) }
                    if(oriented !== image) oriented.recycle(); image.recycle(); merged.recycle(); watermark.recycle()
                    save()
                } catch (e: Throwable) { main.post { failure(e) } }
            }
            return
        }
        try {
            val meta = MediaMetadataRetriever()
            val width: Int
            val height: Int
            try {
                meta.setDataSource(path)
                val w = meta.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toInt() ?: 720
                val h = meta.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toInt() ?: 1280
                val rotated = (meta.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toInt() ?: 0) % 180 != 0
                width = if(rotated) h else w; height = if(rotated) w else h
            } finally { meta.release() }
            val watermark = overlay(width, height, owner)
            val effects = Effects(emptyList(), listOf(OverlayEffect(ImmutableList.of<androidx.media3.effect.TextureOverlay>(BitmapOverlay.createStaticBitmapOverlay(watermark)))))
            val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(source))).setEffects(effects).build()
            transformer = Transformer.Builder(activity).setVideoMimeType(MimeTypes.VIDEO_H264)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        transformer = null; watermark.recycle(); save()
                    }
                    override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) {
                        transformer = null; watermark.recycle(); failure(exportException)
                    }
                }).build()
            transformer!!.start(item, output.absolutePath)
        } catch(e: Throwable) { failure(e) }
    }
}
