package com.tntlikely.beecount

import android.accessibilityservice.AccessibilityService
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.content.pm.ApplicationInfo
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.util.UUID
import java.io.FileDescriptor
import java.io.PrintWriter

class PaymentAccessibilityService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private var receiptSignature: String? = null
    private var lastPackage: String? = null
    private var scheduled = false
    private var lastDiagnostic: String? = null
    private var paymentActivity: String? = null
    private var paymentWindowId = -1
    private var pageGeneration = 0
    private var ocrAttempts = 0
    private var destroyed = false
    private var debugLastOcrText: String? = null
    private val screenshotReader by lazy { PaymentScreenshotReader(this, ::diagnose) }
    private val scan = Runnable { scheduled = false; inspectPage() }
    private fun scheduleScan(delay: Long = 600) {
        // Throttle instead of continually postponing while a page sends content events.
        if (!scheduled && !destroyed) { scheduled = true; handler.postDelayed(scan, delay) }
    }
    override fun onServiceConnected() { super.onServiceConnected(); scheduleScan() }
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val pkg = event?.packageName?.toString()
        if (pkg == null) { scheduleScan(); return }
        if (pkg != lastPackage) receiptSignature = null
        lastPackage = pkg
        if (pkg !in PaymentTextParser.packages || !PaymentCaptureStore.enabled(this, "page")) return
        if (event?.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            event.className?.toString()?.startsWith("$pkg.") == true) {
            val activity = event.className?.toString()
            if (activity != paymentActivity || event.windowId != paymentWindowId) {
                pageGeneration++
                ocrAttempts = 0
                receiptSignature = null
                debugLastOcrText = null
            }
            paymentActivity = activity
            paymentWindowId = event.windowId
            getSharedPreferences("payment_capture", MODE_PRIVATE).edit()
                .putString("pageActivity", activity).apply()
        }
        scheduleScan()
    }
    private fun inspectPage() {
        if (!PaymentCaptureStore.enabled(this, "page")) return
        val root = rootInActiveWindow ?: run { diagnose("root_unavailable"); return }
        val pkg = root.packageName?.toString() ?: return
        if (pkg !in PaymentTextParser.packages) return
        val lines = linkedSetOf<String>()
        var visited = 0
        fun visit(node: AccessibilityNodeInfo, depth: Int) {
            if (++visited > 500 || depth > 40 || node.isPassword) return
            // Some containers have no bounds while their child text is visible.
            if (node.isVisibleToUser) {
                node.text?.toString()?.takeIf { it.isNotBlank() }?.let { lines.add(it) }
                node.contentDescription?.toString()?.takeIf { it.isNotBlank() }?.let { lines.add(it) }
            }
            for(i in 0 until node.childCount.coerceAtMost(60)) node.getChild(i)?.let { visit(it, depth + 1) }
        }
        visit(root, 0)
        val text = lines.joinToString("\n").take(12000)
        if (PaymentOcrPolicy.isRedPacket(pkg, paymentActivity)) {
            tryOcr(pkg, root.windowId)
            return
        }
        val parsed = PaymentTextParser.parse(pkg, text, true)
        diagnose("package=$pkg nodes=$visited chars=${text.length} result=${parsed?.kind ?: "unmatched"} amountKnown=${parsed?.amount != null}")
        if (parsed == null) {
            tryOcr(pkg, root.windowId)
            return
        }
        capture(pkg, text, "page", parsed)
    }
    private fun capture(pkg: String, text: String, source: String, parsed: PaymentTextParser.Payment) {
        val signature = "$pkg:${parsed.kind}:${parsed.amount}:${parsed.merchant}:${parsed.orderId}"
        if (receiptSignature == signature) return
        runCatching { PaymentCaptureStore.capture(this, pkg, text, source, UUID.randomUUID().toString(), System.currentTimeMillis()) }
            .onSuccess { receiptSignature = signature }
            .onFailure { diagnose("capture_failed:${it.javaClass.simpleName}") }
    }
    private fun tryOcr(pkg: String, windowId: Int) {
        if (receiptSignature != null || ocrAttempts >= 3 || windowId != paymentWindowId ||
            !PaymentOcrPolicy.allows(pkg, paymentActivity) || !PaymentCaptureStore.enabled(this, "page_ocr")) return
        val generation = pageGeneration
        fun stillAllowed(): Boolean {
            if (destroyed || generation != pageGeneration || !PaymentCaptureStore.enabled(this, "page_ocr") ||
                !PaymentOcrPolicy.allows(pkg, paymentActivity)) return false
            val root = rootInActiveWindow ?: return false
            return root.packageName?.toString() == pkg && root.windowId == windowId
        }
        if (screenshotReader.read(windowId, ::stillAllowed) { result ->
            if (!stillAllowed()) return@read
            val text = result?.text
            if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0) debugLastOcrText = text
            if (PaymentOcrPolicy.isRedPacket(pkg, paymentActivity)) {
                val receipt = result?.let { WechatRedPacketParser.parse(pkg, paymentActivity, it.lines) }
                if (text != null) diagnose("redpacket_ocr chars=${text.length} matched=${receipt != null} amountKnown=${receipt?.payment?.amount != null}")
                if (receipt != null) {
                    val signature = "$pkg:redpacket:${receipt.fingerprint}"
                    if (receiptSignature != signature) {
                        runCatching { PaymentCaptureStore.captureRedPacket(this, receipt, windowId, System.currentTimeMillis()) }
                            .onSuccess { receiptSignature = signature }
                            .onFailure { diagnose("capture_failed:${it.javaClass.simpleName}") }
                    }
                } else if (ocrAttempts < 3) scheduleScan(3000)
                return@read
            }
            val parsed = text?.let { PaymentTextParser.parse(pkg, it, true, ocr = true) }
            if (text != null) diagnose("ocr_chars=${text.length} result=${parsed?.kind ?: "unmatched"} amountKnown=${parsed?.amount != null}")
            if (parsed != null) capture(pkg, text!!, "page_ocr", parsed)
            else if (ocrAttempts < 3) scheduleScan(3000)
        }) ocrAttempts++
    }
    private fun diagnose(summary: String) {
        // Metadata only: never put payment text, amounts, names or order IDs in logcat.
        if (summary != lastDiagnostic) {
            lastDiagnostic = summary
            getSharedPreferences("payment_capture", MODE_PRIVATE).edit()
                .putString("pageDiagnostic", summary)
                .putLong("pageDiagnosticTime", System.currentTimeMillis()).apply()
            Log.d("BeePaymentCapture", summary)
        }
    }
    override fun dump(fd: FileDescriptor?, writer: PrintWriter?, args: Array<out String>?) {
        // Explicit USB-debug inspection only, never logcat or disk; disabled in release apps.
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0 && args?.contains("--ocr-text") == true) {
            writer?.println(debugLastOcrText ?: "No OCR text available")
        } else writer?.println(lastDiagnostic ?: "No page diagnostic available")
    }
    override fun onInterrupt() { handler.removeCallbacks(scan); scheduled = false }
    override fun onDestroy() {
        destroyed = true
        debugLastOcrText = null
        handler.removeCallbacks(scan)
        scheduled = false
        screenshotReader.close()
        super.onDestroy()
    }
}
