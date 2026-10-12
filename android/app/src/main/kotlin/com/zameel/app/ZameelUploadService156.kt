package com.zameel.app

import android.app.Service
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

class ZameelUploadService156 : Service() {
    private var wake: PowerManager.WakeLock? = null
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel("zameel_uploads156", "عمليات رفع زميل", NotificationManager.IMPORTANCE_LOW))
        val notification = builder(this, "zameel_uploads156").setContentTitle("جارٍ رفع المحتوى")
            .setContentText("يمكنك استخدام زميل؛ سيصلك إشعار عند اكتمال النشر")
            .setSmallIcon(R.mipmap.ic_launcher).setOngoing(true).setContentIntent(openTasks(this)).build()
        if (Build.VERSION.SDK_INT >= 29) startForeground(1560, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        else startForeground(1560, notification)
        if (wake?.isHeld != true) {
            wake = (getSystemService(Context.POWER_SERVICE) as PowerManager).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "zameel:uploads156")
            wake?.acquire(15 * 60 * 1000L)
        }
        return START_NOT_STICKY
    }
    override fun onTimeout(startId: Int, fgsType: Int) { stopSelf() }
    override fun onDestroy() { if (wake?.isHeld == true) wake?.release(); wake = null; super.onDestroy() }
    companion object {
        private fun builder(context: Context, channel: String): Notification.Builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, channel) else Notification.Builder(context)
        private fun openTasks(context: Context): PendingIntent = PendingIntent.getActivity(context, 156, Intent(context, MainActivity::class.java).setAction(Intent.ACTION_VIEW).setData(Uri.parse("zameel://uploads")).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        fun failed(context: Context, id: String) {
            val manager = context.getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel("zameel_upload_errors156", "نتائج رفع زميل", NotificationManager.IMPORTANCE_DEFAULT))
            manager.notify(id.hashCode(), builder(context, "zameel_upload_errors156").setSmallIcon(R.mipmap.ic_launcher).setContentTitle("تعذر رفع المحتوى").setContentText("افتح عمليات الرفع لإعادة المحاولة").setAutoCancel(true).setContentIntent(openTasks(context)).build())
        }
    }
}
