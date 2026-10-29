import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../transaction/transaction_editor_page.dart';

/// Both the home preview and inbox use the same idempotent confirmation flow.
Future<void> reviewPaymentCapture(
    BuildContext context, Map<String, dynamic> item) async {
  const channel = MethodChannel('com.tntlikely.beecount/payment_capture');
  await Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => TransactionEditorPage(
      initialKind: item['kind'] == 'income' ? 'income' : 'expense',
      quickAdd: true,
      creationSyncId: item['id'] as String,
      initialAmount: double.tryParse(item['amount']?.toString() ?? ''),
      initialDate: DateTime.fromMillisecondsSinceEpoch(item['time'] as int),
      initialCurrencyCode: 'CNY',
      initialNote: item['scene'] == 'wechat_redpacket'
          ? '微信红包（请核对本人领取金额）'
          : item['merchant'] as String? ??
              (item['kind'] == 'income' ? '收款识别（请核对付款方）' : '支付识别（请核对商户）'),
      onTransactionCreated: (_) async {
        try {
          await channel.invokeMethod<void>('remove', {'id': item['id']});
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('账目已保存，但待确认记录未移除；请勿重复保存，请返回后忽略该记录。'),
            ));
          }
        }
      },
    ),
  ));
}
