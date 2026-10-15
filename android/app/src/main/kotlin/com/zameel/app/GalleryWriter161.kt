package com.zameel.app

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Legacy Android gallery writes require permission; success means a MediaStore entry exists. */
class GalleryWriter161(private val activity: MainActivity) {
    private data class Pending(val file: File, val mime: String, val name: String,
        val result: MethodChannel.Result, val done: () -> Unit)
    private var pending: Pending? = null
    fun save(file: File, mime: String, name: String, result: MethodChannel.Result, done: () -> Unit) {
        if (pending != null) { result.error("save_busy", "يوجد حفظ قيد التنفيذ", null); done(); return }
        pending = Pending(file, mime, name, result, done)
        if (Build.VERSION.SDK_INT < 29 && activity.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            activity.requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), 161)
        } else write()
    }
    fun permission(requestCode: Int, grants: IntArray): Boolean {
        if (requestCode != 161) return false
        if (grants.isNotEmpty() && grants[0] == PackageManager.PERMISSION_GRANTED) write()
        else finishError("permission_denied", "يلزم السماح بحفظ الوسائط في الاستديو")
        return true
    }
    private fun finishError(code: String, message: String) {
        val job = pending ?: return
        pending = null; job.done(); job.result.error(code, message, null)
    }
    private fun write() {
        val job = pending ?: return
        Thread {
            var target: android.net.Uri? = null
            try {
                require(job.file.isFile && job.file.length() > 0)
                val video = job.mime.startsWith("video/")
                val audio = job.mime.startsWith("audio/")
                val collection = if (video) MediaStore.Video.Media.EXTERNAL_CONTENT_URI else if (audio) MediaStore.Audio.Media.EXTERNAL_CONTENT_URI else MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                val folder = if (video) Environment.DIRECTORY_MOVIES else if (audio) Environment.DIRECTORY_MUSIC else Environment.DIRECTORY_PICTURES
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, job.name)
                    put(MediaStore.MediaColumns.MIME_TYPE, job.mime)
                    if (Build.VERSION.SDK_INT >= 29) {
                        put(MediaStore.MediaColumns.RELATIVE_PATH, "$folder/Zameel")
                        put(MediaStore.MediaColumns.IS_PENDING, 1)
                    } else {
                        @Suppress("DEPRECATION")
                        val directory = File(Environment.getExternalStoragePublicDirectory(folder), "Zameel")
                        require(directory.isDirectory || directory.mkdirs())
                        @Suppress("DEPRECATION")
                        put(MediaStore.MediaColumns.DATA, File(directory, job.name).absolutePath)
                    }
                }
                val uri = activity.contentResolver.insert(collection, values) ?: error("gallery_insert_failed")
                target = uri
                activity.contentResolver.openOutputStream(uri).use { out ->
                    requireNotNull(out); job.file.inputStream().use { it.copyTo(out) }
                }
                if (Build.VERSION.SDK_INT >= 29) {
                    values.clear(); values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                    require(activity.contentResolver.update(uri, values, null, null) == 1)
                }
                if (job.file.name.startsWith("zameel_export_")) job.file.delete()
                activity.runOnUiThread { pending = null; job.done(); job.result.success(uri.toString()) }
            } catch (error: Exception) {
                target?.let { activity.contentResolver.delete(it, null, null) }
                activity.runOnUiThread { finishError("save_failed", "تعذر حفظ الوسائط في الاستديو") }
            }
        }.start()
    }
}
