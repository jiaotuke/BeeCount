import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../transaction/transaction_editor_page.dart';

/// Android native inbox is retained even while Flutter is not running.
class PaymentCapturePage extends StatefulWidget {
  const PaymentCapturePage({super.key});
  @override
  State<PaymentCapturePage> createState() => _PaymentCapturePageState();
}

class _PaymentCapturePageState extends State<PaymentCapturePage>
    with WidgetsBindingObserver {
  static const _channel =
      MethodChannel('com.tntlikely.beecount/payment_capture');
  Map<String, dynamic> _status = {};
  List<Map<String, dynamic>> _items = [];
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_reload());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_reload());
  }

  Future<void> _reload() async {
    try {
      final status = await _channel.invokeMapMethod<String, dynamic>('status');
      final raw = await _channel.invokeMethod<String>('list');
      final items = (jsonDecode(raw ?? '[]') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mounted) {
        setState(() {
          _status = status ?? {};
          _items = items.reversed.toList();
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '读取失败，请刷新重试。待确认账目仍保存在本机。');
    }
  }

  Future<void> _enable(String source, bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (value) {
        final accepted = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
                  title: const Text('允许识别支付信息？'),
                  content: Text(source == 'notification'
                      ? '系统通知访问权限可能接触其他通知。本功能仅处理微信、支付宝的支付文字，在本机生成待确认账目，不上传通知；聊天、验证码不用于记账。开启后还需在系统设置中授权。'
                      : '无障碍权限用于读取微信、支付宝支付成功页面的文字。不点击、不付款、不截取其他应用页面，信息仅保存在本机。可随时关闭。开启后还需在系统设置中授权。'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('取消')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('同意并继续'))
                  ],
                ));
        if (accepted != true) return;
      }
      await _channel.invokeMethod<void>(
          'setEnabled', {'source': source, 'enabled': value});
      if (value &&
          _status[source == 'page' ? 'pageGranted' : 'notificationGranted'] !=
              true) {
        await _channel.invokeMethod<void>(source == 'page'
            ? 'accessibilitySettings'
            : 'notificationSettings');
      }
      await _reload();
    } catch (_) {
      if (mounted) setState(() => _error = '操作失败，请刷新后重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(Map<String, dynamic> item) async {
    if (_busy) return;
    // Saving uses the existing category/account editor, rather than guessing an account.
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => TransactionEditorPage(
              initialKind: 'expense',
              quickAdd: true,
              creationSyncId: item['id'] as String,
              initialAmount: double.tryParse(item['amount']?.toString() ?? ''),
              initialDate:
                  DateTime.fromMillisecondsSinceEpoch(item['time'] as int),
              initialCurrencyCode: 'CNY',
              initialNote: item['merchant'] as String? ?? '支付识别（请核对商户）',
              onTransactionCreated: (_) async {
                try {
                  await _channel
                      .invokeMethod<void>('remove', {'id': item['id']});
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('账目已保存，但待确认记录未移除；请勿重复保存，请返回后忽略该记录。')));
                  }
                }
              },
            )));
    await _reload();
  }

  Future<void> _discard(Map<String, dynamic> item) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('忽略这条记录？'),
              content: const Text('仅移除待确认记录，不会删除已保存的账目。'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('忽略'))
              ],
            ));
    if (yes != true) return;
    try {
      await _channel.invokeMethod<void>('remove', {'id': item['id']});
      await _reload();
    } catch (_) {
      if (mounted) setState(() => _error = '移除失败，请重试。');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('支付自动识别（试验版）'), actions: [
          IconButton(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              tooltip: '刷新'),
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text(
              '微信 / 支付宝付款后自动捕获，确认分类、账户和金额后入账。无需截图，不依赖 AI。当前仅处理人民币消费；转账、退款等暂不处理。'),
          SwitchListTile(
              title: const Text('监听支付通知'),
              subtitle: Text(_status['notificationGranted'] == true
                  ? '系统权限已授权'
                  : '需要通知访问权限'),
              value: _status['notification'] == true,
              onChanged: _busy ? null : (v) => _enable('notification', v)),
          TextButton(
              onPressed: () =>
                  _channel.invokeMethod<void>('notificationSettings'),
              child: const Text('打开通知访问设置')),
          SwitchListTile(
              title: const Text('识别支付成功页面'),
              subtitle:
                  Text(_status['pageGranted'] == true ? '系统权限已授权' : '需要无障碍权限'),
              value: _status['page'] == true,
              onChanged: _busy ? null : (v) => _enable('page', v)),
          TextButton(
              onPressed: () =>
                  _channel.invokeMethod<void>('accessibilitySettings'),
              child: const Text('打开无障碍设置')),
          const Text(
              '关闭上面的开关即停止处理；也可在系统设置撤销权限。没有支付通知、页面文字不可读或系统停止服务时可能漏记。请定期用原始账单核对。'),
          if (_error != null)
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (_status['full'] == true)
            const Text('待确认列表已满（500条），已暂停接收。请先处理记录，并核对此期间的支付账单。'),
          const SizedBox(height: 20),
          Text('待确认 ${_items.length} 条',
              style: Theme.of(context).textTheme.titleLarge),
          if (_items.isEmpty)
            const Padding(
                padding: EdgeInsets.all(16),
                child: Text('暂未捕获付款。授权后完成一笔付款，再回到这里刷新。')),
          for (final item in _items)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            item['amount'] == null
                                ? '金额待核对'
                                : '¥${item['amount']}',
                            style: Theme.of(context).textTheme.titleLarge),
                        Text(
                            '${item['package'] == 'com.tencent.mm' ? '微信' : '支付宝'} · ${item['source'] == 'page' ? '支付页面' : '通知'} · ${DateTime.fromMillisecondsSinceEpoch(item['time'] as int).toLocal()}'),
                        if (item['possibleDuplicate'] == true)
                          const Text('可能与另一条记录重复，请核对后只保存一次。'),
                        ExpansionTile(
                            title: const Text('查看识别原文'),
                            children: [SelectableText(item['text'] as String)]),
                        Row(children: [
                          FilledButton(
                              onPressed: () => _review(item),
                              child: const Text('核对并记账')),
                          TextButton(
                              onPressed: () => _discard(item),
                              child: const Text('忽略'))
                        ]),
                      ],
                    ))),
        ]),
      );
}
