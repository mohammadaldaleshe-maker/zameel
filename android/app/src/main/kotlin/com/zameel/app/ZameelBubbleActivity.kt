package com.zameel.app

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * Lightweight entry activity for an expanded Android system bubble.
 * It immediately launches MainActivity inside the bubble task (without
 * FLAG_ACTIVITY_NEW_TASK), so Flutter and app_links can route the zameel://chat
 * URI normally while the conversation remains inside the bubble window.
 */
class ZameelBubbleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val target = Intent(Intent.ACTION_VIEW, intent?.data, this, MainActivity::class.java).apply {
            intent?.extras?.let { putExtras(it) }
        }
        startActivity(target)
        finish()
    }
}
