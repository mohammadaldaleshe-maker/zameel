package com.zameel.app

import android.content.Context
import android.app.NotificationManager
import android.os.SystemClock

/** Device-local backstop for an FCM packet already in flight when chat opens. */
object ZameelChatVisibility {
    private const val PREFS = "zameel_visible_chat_153"
    fun setForeground(context: Context, foreground: Boolean) {
        val edit = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean("foreground", foreground)
        if (!foreground) edit.remove("conversation").remove("expires")
        edit.apply()
    }
    fun set(context: Context, conversation: String?, user: String?) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val edit = prefs.edit()
        if (conversation.isNullOrBlank() || user.isNullOrBlank() || !prefs.getBoolean("foreground", false)) {
            edit.remove("conversation").remove("expires").apply()
            return
        }
        edit.putString("conversation", conversation).putLong("expires", SystemClock.elapsedRealtime() + 15_000L).apply()
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .cancel(conversation.hashCode() and 0x7fffffff)
    }
    fun isVisible(context: Context, conversation: String): Boolean {
        if (conversation.isBlank()) return false
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val remaining = prefs.getLong("expires", 0L) - SystemClock.elapsedRealtime()
        return prefs.getBoolean("foreground", false) &&
            conversation == prefs.getString("conversation", null) && remaining in 1L..15_000L
    }
}
