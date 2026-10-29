import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'payment_capture_review.dart';

/// Android native inbox is retained even while Flutter is not running.
class PaymentCapturePage extends StatefulWidget {
  final bool showSettings;
  const PaymentCapturePage({super.key, this.showSettings = true});
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
                  title: Text(source == 'ocr' ? '开启本地截图文字识别？' : '允许识别支付信息？'),
                  content: Text(source == 'notification'
                      ? '系统通知访问权限可能接触其他通知。本功能仅处理微信、支付宝的付款与收款文字，在本机生成待确认账目，不上传通知；聊天、验证码不用于记账。开启后还需在系统设置中授权。'
                      : source == 'ocr'
                          ? '当页面文字不可读时，截取指定收付款详情页并在手机本地识别。当前仅适配微信转账收款详情，不截取聊天、密码或其他应用页面。截图只在内存处理，不上传、不存入相册；识别文字作为待确认记录保存在本机。使用内置 ML Kit OCR，SDK 可能发送性能和使用统计，不发送识别图片或文字。系统禁止截图时停止。此开关默认关闭，可随时关闭。'
                          : '无障碍权限用于读取微信、支付宝付款成功和收款到账页面的文字。不点击、不付款、不截取其他应用页面。截图识别需另行开启；信息仅保存在本机。可随时关闭。开启后还需在系统设置中授权。'),
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
          source != 'ocr' &&
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
    await reviewPaymentCapture(context, item);
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
        appBar: AppBar(
            title: Text(widget.showSettings ? '支付自动识别（试验版）' : '待确认收支'),
            actions: [
              if (!widget.showSettings)
                IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: '识别设置',
                    onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => const PaymentCapturePage()));
                      await _reload();
                    }),
              IconButton(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  tooltip: '刷新'),
            ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (widget.showSettings) ...[
            const Text(
                '微信 / 支付宝付款、收款到账后自动捕获，确认分类、账户和金额后记为支出或收入。默认读取通知和页面文字，可另行开启本地截图识别，不调用云端 AI。仅处理人民币；退款、充值、提现和未确认的转账暂不处理。'),
            SwitchListTile(
                title: const Text('监听付款与收款通知'),
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
                title: const Text('识别付款成功与收款到账页面'),
                subtitle: Text(
                    _status['pageGranted'] == true ? '系统权限已授权' : '需要无障碍权限'),
                value: _status['page'] == true,
                onChanged: _busy ? null : (v) => _enable('page', v)),
            TextButton(
                onPressed: () =>
                    _channel.invokeMethod<void>('accessibilitySettings'),
                child: const Text('打开无障碍设置')),
            SwitchListTile(
                title: const Text('本地截图文字识别兜底'),
                subtitle: Text(_status['ocrSupported'] != true
                    ? '需要 Android 11 或更新版本'
                    : _status['page'] != true
                        ? '请先开启上面的页面识别'
                        : '仅适配微信转账收款详情；不上传、不保存截图'),
                value: _status['ocr'] == true,
                onChanged: _busy ||
                        _status['ocrSupported'] != true ||
                        _status['page'] != true
                    ? null
                    : (v) => _enable('ocr', v)),
            if (_status['pageDiagnostic']?.toString().contains('chars=0') ==
                true)
              const Text('页面没有提供可读取文字；可按需开启本地截图识别，或使用通知识别。'),
            if (_status['pageDiagnostic']
                    ?.toString()
                    .startsWith('ocr_screenshot_unavailable:') ==
                true)
              const Text('系统暂不允许截取此页面，请使用通知识别或手动录入。'),
            const Text(
                '关闭上面的开关即停止处理；也可在系统设置撤销权限。没有支付通知、页面文字不可读或系统停止服务时可能漏记。请定期用原始账单核对。'),
          ],
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
                child: Text('暂未捕获收支。授权后完成一笔付款或收款，再回到这里刷新。')),
          for (final item in _items)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['kind'] == 'income'
                            ? '待确认收入 · 收款'
                            : '待确认支出 · 付款'),
                        Text(
                            item['amount'] == null
                                ? '金额待核对'
                                : '¥${item['amount']}',
                            style: Theme.of(context).textTheme.titleLarge),
                        Text(
                            '${item['package'] == 'com.tencent.mm' ? '微信' : '支付宝'} · ${item['source'] == 'page_ocr' ? '本地截图识别' : item['source'] == 'page' ? '支付页面' : '通知'} · ${DateTime.fromMillisecondsSinceEpoch(item['time'] as int).toLocal()}'),
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
