package com.tntlikely.beecount

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

object PaymentCaptureChannel {
    fun register(activity: FlutterFragmentActivity, messenger: BinaryMessenger) {
        MethodChannel(messenger, "com.tntlikely.beecount/payment_capture").setMethodCallHandler { call, result ->
            try {
                when(call.method) {
                    "status" -> {
                        val notificationComponent = ComponentName(activity, PaymentNotificationListener::class.java).flattenToString()
                        val accessibilityComponent = ComponentName(activity, PaymentAccessibilityService::class.java).flattenToString()
                        fun granted(key: String, component: String): Boolean = Settings.Secure.getString(activity.contentResolver, key)
                            ?.split(':')?.any { ComponentName.unflattenFromString(it)?.flattenToString() == component } == true
                        result.success(mapOf("notification" to PaymentCaptureStore.enabled(activity, "notification"),
                            "page" to PaymentCaptureStore.enabled(activity, "page"), "full" to PaymentCaptureStore.full(activity),
                            "ocr" to PaymentCaptureStore.enabled(activity, "ocr"), "ocrSupported" to (Build.VERSION.SDK_INT >= 30),
                            "pageDiagnostic" to activity.getSharedPreferences("payment_capture", 0).getString("pageDiagnostic", null),
                            "notificationGranted" to granted("enabled_notification_listeners", notificationComponent),
                            "pageGranted" to granted(Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES, accessibilityComponent)))
                    }
                    "setEnabled" -> {
                        PaymentCaptureStore.setEnabled(activity, call.argument<String>("source")!!, call.argument<Boolean>("enabled")!!)
                        result.success(null)
                    }
                    "notificationSettings" -> { activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)); result.success(null) }
                    "accessibilitySettings" -> { activity.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)); result.success(null) }
                    "list" -> result.success(PaymentCaptureStore.list(activity).toString())
                    "remove" -> { PaymentCaptureStore.remove(activity, call.argument<String>("id")!!); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch(e: Exception) { result.error("payment_capture", e.message, null) }
        }
    }
}
