package com.tntlikely.beecount

import java.math.BigDecimal

/** Conservative CNY extraction. Never infer success or an amount from unrelated numbers. */
object PaymentTextParser {
    val packages = setOf("com.tencent.mm", "com.eg.android.AlipayGphone")
    data class Payment(val amount: String?, val merchant: String?, val orderId: String?)
    private val currency = Regex("(?:[¥￥]\\s*([0-9]+(?:\\.[0-9]{1,2})?)(?![0-9.])|(?<![0-9.])([0-9]+(?:\\.[0-9]{1,2})?)\\s*元)")
    fun parse(packageName: String, text: String, page: Boolean): Payment? {
        if (packageName !in packages || text.length > 12000) return null
        // These flows need separate accounting rules; do not classify them as consumption.
        if (Regex("退款|退回|转账|收款(?!方|人)|到账|还款|充值|提现|支付失败|付款失败|待支付|等待付款|验证码|动态码").containsMatchIn(text)) return null
        val success = if (page) Regex("支付成功|付款成功") else Regex("支付成功|付款成功|已支付|扣款成功|交易成功|支付凭证|支出|消费")
        if (!success.containsMatchIn(text)) return null
        val amounts = currency.findAll(text).mapNotNull {
            val value = it.groups[1]?.value ?: it.groups[2]?.value ?: return@mapNotNull null
            runCatching { BigDecimal(value).setScale(2).toPlainString() }.getOrNull()
        }.filter { BigDecimal(it).signum() > 0 }.toSet()
        val merchant = Regex("(?:收款方|商户(?:名称)?|商家|商品说明)[:：\\s]+([^\\n]{1,80})").find(text)?.groupValues?.get(1)?.trim()
        val order = Regex("(?:商户订单号|交易单号|订单号)[:：\\s]+([A-Za-z0-9_-]{6,80})").find(text)?.groupValues?.get(1)
        return Payment(amounts.singleOrNull(), merchant, order)
    }
}
