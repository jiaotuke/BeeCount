package com.tntlikely.beecount

import android.accessibilityservice.AccessibilityService
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.util.UUID

class PaymentAccessibilityService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private var receiptSignature: String? = null
    private var lastPackage: String? = null
    private val scan = Runnable { inspectPage() }
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val pkg = event?.packageName?.toString() ?: return
        if (pkg != lastPackage) receiptSignature = null
        lastPackage = pkg
        handler.removeCallbacks(scan)
        if (pkg !in PaymentTextParser.packages || !PaymentCaptureStore.enabled(this, "page")) return
        handler.postDelayed(scan, 600)
    }
    private fun inspectPage() {
        if (!PaymentCaptureStore.enabled(this, "page")) return
        val root = rootInActiveWindow ?: return
        val pkg = root.packageName?.toString() ?: return
        if (pkg !in PaymentTextParser.packages) return
        val lines = linkedSetOf<String>()
        var visited = 0
        fun visit(node: AccessibilityNodeInfo, depth: Int) {
            if (++visited > 250 || depth > 20 || node.isPassword || !node.isVisibleToUser) return
            node.text?.toString()?.takeIf { it.isNotBlank() }?.let { lines.add(it) }
            node.contentDescription?.toString()?.takeIf { it.isNotBlank() }?.let { lines.add(it) }
            for(i in 0 until node.childCount.coerceAtMost(60)) node.getChild(i)?.let { visit(it, depth + 1) }
        }
        visit(root, 0)
        val text = lines.joinToString("\n").take(12000)
        val parsed = PaymentTextParser.parse(pkg, text, true)
        if (parsed == null) { receiptSignature = null; return }
        val signature = "$pkg:${parsed.kind}:${parsed.amount}:${parsed.merchant}:${parsed.orderId}"
        if (receiptSignature == signature) return
        receiptSignature = signature
        runCatching { PaymentCaptureStore.capture(this, pkg, text, "page", UUID.randomUUID().toString(), System.currentTimeMillis()) }
    }
    override fun onInterrupt() { handler.removeCallbacks(scan) }
    override fun onDestroy() { handler.removeCallbacks(scan); super.onDestroy() }
}
