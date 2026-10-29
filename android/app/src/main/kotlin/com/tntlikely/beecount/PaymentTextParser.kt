package com.tntlikely.beecount

import java.math.BigDecimal

/** Conservative CNY extraction. Never infer success or an amount from unrelated numbers. */
object PaymentTextParser {
    val packages = setOf("com.tencent.mm", "com.eg.android.AlipayGphone")
    data class Payment(val amount: String?, val merchant: String?, val orderId: String?, val kind: String = "expense", val scene: String = "payment")
    private val currency = Regex("(?:[¥￥]\\s*([0-9]+(?:\\.[0-9]{1,2})?)(?![0-9.])|(?<![0-9.])([0-9]+(?:\\.[0-9]{1,2})?)\\s*元)")
    fun parse(packageName: String, text: String, page: Boolean, ocr: Boolean = false): Payment? {
        if (text.length > 12000) return null
        // OCR-only correction of the received-state label. Never substitute amount digits.
        val normalized = if (ocr) text
            .replace(Regex("(?<=\\p{IsHan})\\s+(?=\\p{IsHan})"), "")
            .replace(Regex("([你您])[己巳]收款")) { "${it.groupValues[1]}已收款" }
            else text
        return parseText(packageName, normalized, page)
    }
    private fun parseText(packageName: String, text: String, page: Boolean): Payment? {
        if (packageName !in packages || text.length > 12000) return null
        // Refunds and balance movements are not ordinary income. A QR request is not a receipt.
        if (Regex("退款|退回|还款|充值|提现|余额转入|内部转账|支付失败|付款失败|收款失败|交易失败|交易关闭|已取消|已撤销|未到账|待收款|等待收款|待支付|待付款|等待付款|等待对方付款|验证码|动态码").containsMatchIn(text)) return null
        val personalReceipt = Regex("[你您]已(?:成功)?收款").containsMatchIn(text)
        val incoming = personalReceipt || Regex("收款到账|收钱到账|收款成功|成功收款|收到(?:一笔)?(?:付款|收款)|(?:支付宝|微信(?:支付)?)到账").containsMatchIn(text) ||
            (!page && Regex("微信支付收款(?!码|二维码)").containsMatchIn(text))
        val outgoing = Regex("支付成功|付款成功|扣款成功|你已付款|您已付款|对方已收款|对方已收钱|支出|消费").containsMatchIn(text)
        if (incoming && outgoing) return null // Contradictory direction: never guess who received money.
        if (Regex("转账").containsMatchIn(text) && !personalReceipt) return null
        if (!incoming) {
            if (Regex("收款(?!方|人)|到账|对方已收钱").containsMatchIn(text)) return null
            val success = if (page) Regex("支付成功|付款成功") else Regex("支付成功|付款成功|已支付|扣款成功|交易成功|支付凭证|支出|消费")
            if (!success.containsMatchIn(text)) return null
        }
        val amounts = currency.findAll(text).mapNotNull {
            val value = it.groups[1]?.value ?: it.groups[2]?.value ?: return@mapNotNull null
            runCatching { BigDecimal(value).setScale(2).toPlainString() }.getOrNull()
        }.filter { BigDecimal(it).signum() > 0 }.toSet()
        val party = if (incoming) "付款方|付款人|来自|对方名称" else "收款方|商户(?:名称)?|商家|商品说明"
        val merchant = Regex("(?:$party)[:：\\s]+([^\\n]{1,80})").find(text)?.groupValues?.get(1)?.trim()
        val order = Regex("(?:商户订单号|交易单号|订单号)[:：\\s]+([A-Za-z0-9_-]{6,80})").find(text)?.groupValues?.get(1)
        return Payment(amounts.singleOrNull(), merchant, order, if (incoming) "income" else "expense")
    }
}
