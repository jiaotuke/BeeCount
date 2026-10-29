package com.tntlikely.beecount

/** Runs with the Kotlin compiler without Android or a device. */
fun main() {
    val wechat = "com.tencent.mm"
    val alipay = "com.eg.android.AlipayGphone"
    check(PaymentTextParser.parse(wechat, "支付成功\n￥18.50\n商户名称：早餐店", true)?.amount == "18.50")
    check(PaymentTextParser.parse(alipay, "付款成功\n收款方：超市\n26元", true)?.merchant == "超市")
    check(PaymentTextParser.parse(alipay, "消费18元，余额900元", false)?.amount == null)
    check(PaymentTextParser.parse(alipay, "支付成功 ¥18.50，优惠后实付 ¥16.50", true)?.amount == null)
    check(PaymentTextParser.parse(wechat, "支付成功\n18.50\n订单号 123456789", true)?.amount == null)
    check(PaymentTextParser.parse(wechat, "支付成功 ¥0", true)?.amount == null)
    check(PaymentTextParser.parse(wechat, "支付成功 ¥18.50 18.50元", true)?.amount == "18.50")
    for (flow in listOf("退款成功", "转账成功", "收款到账", "还款成功", "充值成功", "待支付", "支付失败", "验证码")) {
        check(PaymentTextParser.parse(wechat, "$flow 支付成功 ¥18.50", true) == null)
    }
    check(PaymentTextParser.parse("com.example.fake", "支付成功 ¥18.50", true) == null)
    check(PaymentTextParser.parse(wechat, "订单金额 ¥18.50", true) == null)
    check(PaymentTextParser.parse(wechat, "支付成功 ¥12.345", true)?.amount == null)
    check(PaymentTextParser.parse(alipay, "支付成功 ¥15 商户订单号：ABC123456", true)?.orderId == "ABC123456")
    println("PaymentTextParser: 13 scenarios passed (including 8 excluded flows)")
}
