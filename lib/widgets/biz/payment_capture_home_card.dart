import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../pages/automation/payment_capture_page.dart';
import '../../pages/automation/payment_capture_review.dart';

class PaymentCaptureHomeCard extends StatefulWidget {
  final bool hideAmounts;
  const PaymentCaptureHomeCard({super.key, this.hideAmounts = false});
  @override
  State<PaymentCaptureHomeCard> createState() => _PaymentCaptureHomeCardState();
}

class _PaymentCaptureHomeCardState extends State<PaymentCaptureHomeCard>
    with WidgetsBindingObserver {
  static const _channel =
      MethodChannel('com.tntlikely.beecount/payment_capture');
  List<Map<String, dynamic>> _items = [];
  String? _lastRaw;
  bool _failed = false;
  bool _loading = true;
  bool _reading = false;
  bool _opening = false;
  bool _resumed = true;
  Timer? _timer;
  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    if (!_supported) return;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_reload());
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_resumed &&
          !_opening &&
          (ModalRoute.of(context)?.isCurrent ?? true) &&
          TickerMode.of(context)) {
        unawaited(_reload());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed) unawaited(_reload());
  }

  Future<void> _reload() async {
    if (_reading) return;
    _reading = true;
    try {
      final raw = await _channel.invokeMethod<String>('list') ?? '[]';
      if (mounted && (raw != _lastRaw || _failed || _loading)) {
        final items = (jsonDecode(raw) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList()
            .reversed
            .toList();
        setState(() {
          _items = items;
          _lastRaw = raw;
          _failed = false;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    } finally {
      _reading = false;
    }
  }

  Future<void> _open([Map<String, dynamic>? item]) async {
    if (_opening) return;
    _opening = true;
    try {
      if (item != null) {
        await reviewPaymentCapture(context, item);
      } else {
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const PaymentCapturePage(showSettings: false),
        ));
      }
    } finally {
      _opening = false;
      if (mounted) await _reload();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          dense: true,
          leading: Icon(Icons.receipt_long_outlined, color: colors.primary),
          title: Text(
              _failed
                  ? '待确认收支读取失败'
                  : '待确认收支${_loading ? '' : ' · ${_items.length} 笔'}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(_failed
              ? '点击重试'
              : _loading
                  ? '正在读取'
                  : _items.isEmpty
                      ? '暂无待确认，自动识别的收支会显示在这里'
                      : '尚未记入账本 · 核对后保存'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _failed ? _reload : () => _open(),
        ),
        if (!_failed)
          for (final item in _items.take(2))
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: Icon(
                  item['kind'] == 'income'
                      ? Icons.south_west
                      : Icons.north_east,
                  size: 20),
              title: Text(
                  '${item['kind'] == 'income' ? '收入' : '支出'} · ${item['scene'] == 'wechat_redpacket' ? '微信红包' : item['package'] == 'com.tencent.mm' ? '微信' : '支付宝'}'),
              subtitle: item['possibleDuplicate'] == true
                  ? const Text('疑似重复，请核对')
                  : null,
              trailing: Text(
                  widget.hideAmounts
                      ? '••••'
                      : item['amount'] == null
                          ? '金额待核对'
                          : '¥${item['amount']}',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: colors.primary)),
              onTap: () => _open(item),
            ),
        if (!_failed && _items.length > 2)
          Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _open(),
                child: Text('查看全部 ${_items.length} 笔'),
              )),
      ]),
    );
  }
}
