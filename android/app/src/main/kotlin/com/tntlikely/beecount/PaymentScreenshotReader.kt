package com.tntlikely.beecount

import android.accessibilityservice.AccessibilityService
import android.graphics.Bitmap
import android.os.Build
import android.os.SystemClock
import android.view.Display
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions

/** Opt-in, bounded, in-memory OCR. No image files or image/text uploads; SDK metrics are disclosed separately. */
class PaymentScreenshotReader(
    private val service: AccessibilityService,
    private val diagnose: (String) -> Unit
) {
    data class Result(val text: String, val lines: List<WechatRedPacketParser.Line>)
    private var recognizer: TextRecognizer? = null
    private var inFlight = false
    private var closed = false
    private var lastAttempt = -10000L

    fun read(windowId: Int, stillAllowed: () -> Boolean, onText: (Result?) -> Unit): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R || closed || inFlight || !stillAllowed()) return false
        val now = SystemClock.elapsedRealtime()
        if (now - lastAttempt < 2500) return false
        lastAttempt = now
        inFlight = true
        diagnose("ocr_capturing")
        val callback = object : AccessibilityService.TakeScreenshotCallback {
            override fun onFailure(errorCode: Int) {
                inFlight = false
                diagnose("ocr_screenshot_unavailable:$errorCode")
                if (!closed && stillAllowed()) onText(null)
            }

            override fun onSuccess(screenshot: AccessibilityService.ScreenshotResult) {
                val buffer = screenshot.hardwareBuffer
                val bitmap = try {
                    val hardware = Bitmap.wrapHardwareBuffer(buffer, screenshot.colorSpace)
                    try { hardware?.copy(Bitmap.Config.ARGB_8888, false) } finally { hardware?.recycle() }
                } catch (_: Exception) { null } finally { buffer.close() }
                if (bitmap == null || closed || !stillAllowed()) {
                    bitmap?.recycle()
                    inFlight = false
                    diagnose("ocr_cancelled_or_bitmap_unavailable")
                    return
                }
                try {
                    val client = recognizer ?: TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
                        .also { recognizer = it }
                    client.process(InputImage.fromBitmap(bitmap, 0))
                        .addOnSuccessListener { result ->
                            if (!closed && stillAllowed()) {
                                val lines = result.textBlocks.flatMap { it.lines }.take(500).mapNotNull { line ->
                                    val box = line.boundingBox ?: return@mapNotNull null
                                    WechatRedPacketParser.Line(line.text, box.left, box.top, box.right, box.bottom)
                                }
                                onText(Result(result.text.take(12000), lines))
                            }
                        }
                        .addOnFailureListener {
                            diagnose("ocr_recognition_failed:${it.javaClass.simpleName}")
                            if (!closed && stillAllowed()) onText(null)
                        }
                        .addOnCompleteListener { bitmap.recycle(); inFlight = false }
                } catch (e: Exception) {
                    bitmap.recycle()
                    inFlight = false
                    diagnose("ocr_initialization_failed:${e.javaClass.simpleName}")
                    if (!closed && stillAllowed()) onText(null)
                }
            }
        }
        try {
            // Android 14+: capture the approved window, never a different app behind/above it.
            if (Build.VERSION.SDK_INT >= 34) service.takeScreenshotOfWindow(windowId, service.mainExecutor, callback)
            else service.takeScreenshot(Display.DEFAULT_DISPLAY, service.mainExecutor, callback)
        } catch (e: Exception) {
            inFlight = false
            diagnose("ocr_capture_failed:${e.javaClass.simpleName}")
            if (!closed && stillAllowed()) onText(null)
        }
        return true
    }

    fun close() { closed = true; recognizer?.close(); recognizer = null }
}
