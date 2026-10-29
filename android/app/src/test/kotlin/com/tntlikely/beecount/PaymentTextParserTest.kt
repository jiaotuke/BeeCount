package com.tntlikely.beecount

/** Runs with the Kotlin compiler without Android or a device. */
fun main() {
    val wechat = "com.tencent.mm"
    val alipay = "com.eg.android.AlipayGphone"
    val receiptActivity = "com.tencent.mm.plugin.remittance.ui.RemittanceDetailUI"
    val packetActivity = "com.tencent.mm.plugin.luckymoney.ui.LuckyMoneyNewDetailUI"
    check(PaymentOcrPolicy.allows(wechat, packetActivity))
    check(!PaymentOcrPolicy.allows(wechat, "com.tencent.mm.plugin.luckymoney.ui.LuckyMoneyBeforeDetailUI"))
    fun line(text: String, top: Int, bottom: Int = top + 25) = WechatRedPacketParser.Line(text, 100, top, 500, bottom)
    val packet = listOf(line("23:01", 10), line("测试甲的红包", 200), line("合成祝福", 245),
        line("12.34", 310, 400), line("元", 365), line("已存入零钱，可直接转账", 440),
        line("共99.00元", 600), line("测试乙", 660), line("88.88元", 700))
    val packetReceipt = WechatRedPacketParser.parse(wechat, packetActivity, packet)!!
    check(packetReceipt.payment.amount == "12.34" && packetReceipt.payment.kind == "income")
    check(packetReceipt.payment.scene == "wechat_redpacket")
    check(!packetReceipt.evidence.contains("88.88") && !packetReceipt.evidence.contains("测试乙"))
    check(WechatRedPacketParser.parse(wechat, packetActivity, packet.drop(1))?.fingerprint == packetReceipt.fingerprint)
    check(WechatRedPacketParser.parse(wechat, packetActivity, packet + line("77.77元", 800))?.fingerprint == packetReceipt.fingerprint)
    check(WechatRedPacketParser.parse(wechat, packetActivity, packet.reversed())?.payment?.amount == "12.34")
    check(WechatRedPacketParser.parse(wechat, packetActivity, packet.filterNot { it.text == "元" }.map {
        if (it.text == "12.34") line("12.34元", 310, 400) else it
    })?.fingerprint == packetReceipt.fingerprint)
    check(WechatRedPacketParser.parse(wechat, receiptActivity, packet) == null)
    check(WechatRedPacketParser.parse(alipay, packetActivity, packet) == null)
    check(WechatRedPacketParser.parse(wechat, packetActivity, packet.filterNot { it.text.contains("已存入") }) == null)
    check(WechatRedPacketParser.parse(wechat, packetActivity, packet.map { if (it.text.contains("已存入")) line("手慢了，红包派完了", 440) else it }) == null)
    check(WechatRedPacketParser.parse(wechat, packetActivity, packet.map { if (it.text.contains("已存入")) line("红包已过期", 440) else it }) == null)
    check(WechatRedPacketParser.parse(wechat, packetActivity, packet.map { if (it.text=="12.34") line("12.OO", 310, 400) else it })?.payment?.amount == null)
    check(WechatRedPacketParser.parse(wechat, packetActivity, packet + line("7.89元", 270))?.payment?.amount == null)
    check(WechatRedPacketParser.parse(wechat, packetActivity, packet.map { if (it.text.contains("已存入")) line("己存人零钱,可直接转账", 440) else it })?.payment?.amount == "12.34")
    check(WechatRedPacketParser.parse(wechat, packetActivity, packet.map {
        when {
            it.text == "12.34" -> line("12.34.", 310, 400)
            it.text.contains("已存入") -> line("已存入零线,可直接转账〉", 440)
            else -> it
        }
    })?.payment?.amount == "12.34")
    check(WechatRedPacketParser.parse(wechat, packetActivity, packet.map {
        if (it.text == "12.34") line("12.345.", 310, 400) else it
    })?.payment?.amount == null)
    check(PaymentOcrPolicy.allows(wechat, receiptActivity))
    check(!PaymentOcrPolicy.allows(alipay, receiptActivity))
    for (activity in listOf(null, "android.webkit.WebView", "com.tencent.mm.ui.LauncherUI", "com.tencent.mm.plugin.wallet.pay.ui.WalletPayUI", receiptActivity + "Fake")) {
        check(!PaymentOcrPolicy.allows(wechat, activity))
    }
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
    val receivedTransferPage = "你已收款，资金已存入零钱\n￥12.34\n零钱余额\n转账时间\n2026年1月1日 10:00:00\n收款时间\n2026年1月1日 10:01:00\n账单详情"
    val receivedTransfer = PaymentTextParser.parse(wechat, receivedTransferPage, true)!!
    check(receivedTransfer.kind == "income" && receivedTransfer.amount == "12.34")
    val ocrTransfer = "转账时间\n收款时间\n你己收款,资金己存入零钱\n¥12.34\n2026年1月1日10:00:00"
    check(PaymentTextParser.parse(wechat, ocrTransfer, true, ocr = true)?.kind == "income")
    check(PaymentTextParser.parse(wechat, ocrTransfer, true, ocr = true)?.amount == "12.34")
    check(PaymentTextParser.parse(wechat, ocrTransfer, true) == null)
    check(PaymentTextParser.parse(wechat, "你 己 收 款\n￥12.34", true, ocr = true)?.kind == "income")
    check(PaymentTextParser.parse(wechat, "你己收款\n￥12.OO", true, ocr = true)?.amount == null)
    check(PaymentTextParser.parse(wechat, "你未收款\n￥12.34", true, ocr = true) == null)
    check(PaymentTextParser.parse(wechat, "对方己收款\n转账时间\n￥12.34", true, ocr = true) == null)
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
