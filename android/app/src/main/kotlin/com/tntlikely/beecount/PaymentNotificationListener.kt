package com.tntlikely.beecount

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class PaymentNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName !in PaymentTextParser.packages || !PaymentCaptureStore.enabled(this, "notification")) return
        if (sbn.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        val extras = sbn.notification.extras ?: return
        // Do not parse ordinary chat conversation notifications as payment receipts.
        if (extras.getString("android.template")?.contains("MessagingStyle") == true) return
        val text = listOfNotNull(extras.getCharSequence(Notification.EXTRA_TITLE)?.toString(),
            extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: extras.getCharSequence(Notification.EXTRA_TEXT)?.toString(),
            extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)?.joinToString("\n"))
            .distinct().joinToString("\n")
        runCatching { PaymentCaptureStore.capture(this, sbn.packageName, text, "notification", "${sbn.key}:${sbn.postTime}", sbn.postTime) }
    }
}
