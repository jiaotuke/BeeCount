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
    val receipt = PaymentTextParser.parse(wechat, "微信支付\n收款到账\n金额：￥50.00\n付款方：张三\n交易单号：RECEIPT001", false)!!
    check(receipt.kind == "income" && receipt.amount == "50.00" && receipt.merchant == "张三")
    check(PaymentTextParser.parse(alipay, "支付宝到账100元", false)?.kind == "income")
    check(PaymentTextParser.parse(wechat, "微信支付收款20元", false)?.kind == "income")
    check(PaymentTextParser.parse(wechat, "收款成功\n￥8.80\n付款人：顾客", true)?.kind == "income")
    check(PaymentTextParser.parse(wechat, "转账\n你已收款\n￥30.00", true)?.kind == "income")
    check(PaymentTextParser.parse(wechat, "转账成功\n对方已收款\n￥30.00", true) == null)
    check(PaymentTextParser.parse(alipay, "收款到账100元\n余额900元", false)?.amount == null)
    check(PaymentTextParser.parse(alipay, "收款成功100元\n手续费1元\n实际到账99元", true)?.amount == null)
    check(PaymentTextParser.parse(wechat, "收款到账\n付款方：顾客", true)?.amount == null)
    for (text in listOf("收款码 ￥50", "微信支付收款码 ￥50", "收款失败 ￥50", "等待收款 ￥50", "微信支付收款 等待对方付款 ￥50", "微信支付收款 已取消 ￥50", "退款到账 收款成功 ￥50", "提现到账 收款成功 ￥50", "内部转账 收款成功 ￥50")) {
        check(PaymentTextParser.parse(wechat, text, false) == null)
    }
    check(PaymentTextParser.parse(wechat, "微信支付收款 ￥50", true) == null) // A page title alone is not a completed receipt.
    check(PaymentTextParser.parse(wechat, "付款成功\n￥18.50\n收款方：超市", true)?.kind == "expense")
    println("PaymentTextParser: expense and income scenarios passed, including ambiguous amounts, unconfirmed QR pages, refunds and outgoing transfers")
}
