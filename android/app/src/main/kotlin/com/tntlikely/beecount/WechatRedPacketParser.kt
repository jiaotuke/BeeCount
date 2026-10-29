package com.tntlikely.beecount

import java.math.BigDecimal
import java.security.MessageDigest

/** Spatial OCR receipt: amounts below the credited-to-balance label are never candidates. */
object WechatRedPacketParser {
    data class Line(val text: String, val left: Int, val top: Int, val right: Int, val bottom: Int)
    data class Receipt(val payment: PaymentTextParser.Payment, val evidence: String, val fingerprint: String)
    private fun compact(text: String) = text.replace(Regex("\\s+"), "")
    private fun credited(text: String) = Regex("[已己巳]存[入人]零[钱线]").containsMatchIn(compact(text))
    private fun amountText(text: String) = compact(text).trimEnd('.', '。', ',', '，')
    private val amount = Regex("^[¥￥]?([0-9]{1,9}\\.[0-9]{2})元?$")

    fun parse(pkg: String, activity: String?, lines: List<Line>): Receipt? {
        if (!PaymentOcrPolicy.isRedPacket(pkg, activity)) return null
        val markers = lines.filter { credited(it.text) }
        if (markers.size != 1) return null
        val marker = markers.single()
        val upper = lines.filter { it.bottom <= marker.top && it.right > it.left && it.bottom > it.top }
            .sortedWith(compareBy<Line> { it.top }.thenBy { it.left })
        val titleIndex = upper.indexOfFirst { compact(it.text).contains("的红包") }
        if (titleIndex < 0) return null
        val header = upper.drop(titleIndex)
        // A date, sender message or participant row must not become the personal amount.
        val candidates = header.mapNotNull { line ->
            val match = amount.matchEntire(amountText(line.text)) ?: return@mapNotNull null
            val value = runCatching { BigDecimal(match.groupValues[1]).setScale(2) }.getOrNull() ?: return@mapNotNull null
            if (value.signum() <= 0 || marker.top - line.bottom > (marker.bottom - marker.top).coerceAtLeast(20) * 8) return@mapNotNull null
            value.toPlainString()
        }.distinct()
        val ownAmount = candidates.singleOrNull()
        val evidence = (header.map { it.text } + marker.text).joinToString("\n").take(12000)
        // This is a similarity fingerprint, not a platform-authenticated packet ID.
        val identityLines = header.map { compact(it.text) }.filter { it != "元" && amount.matchEntire(amountText(it)) == null }
        val stableHeader = identityLines.joinToString("|") + "|" + (ownAmount ?: "unknown")
        val fingerprint = MessageDigest.getInstance("SHA-256").digest(stableHeader.toByteArray())
            .joinToString("") { "%02x".format(it) }
        return Receipt(PaymentTextParser.Payment(ownAmount, "微信红包", null, "income", "wechat_redpacket"), evidence, fingerprint)
    }
}
