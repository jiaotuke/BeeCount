package com.tntlikely.beecount

/** Intentionally narrow: never allow generic WebViews, chats, QR requests or pay/password UIs. */
object PaymentOcrPolicy {
    fun allows(packageName: String?, activity: String?): Boolean =
        packageName == "com.tencent.mm" &&
            (activity == "com.tencent.mm.plugin.remittance.ui.RemittanceDetailUI" || isRedPacket(packageName, activity))

    fun isRedPacket(packageName: String?, activity: String?): Boolean =
        packageName == "com.tencent.mm" &&
            activity == "com.tencent.mm.plugin.luckymoney.ui.LuckyMoneyNewDetailUI"
}
