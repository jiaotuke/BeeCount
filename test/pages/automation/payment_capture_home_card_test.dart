import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/widgets/biz/payment_capture_home_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.tntlikely.beecount/payment_capture');
  var fail = false;
  var items = <Map<String, dynamic>>[];
  Map<String, dynamic> record(String id, String? amount, String kind) => {
        'id': id,
        'amount': amount,
        'kind': kind,
        'package': 'com.tencent.mm',
        'source': 'notification',
        'time': 1700000000000,
        'text': '合成样本',
      };
  setUp(() {
    fail = false;
    items = [
      record('old', '8.00', 'expense'),
      record('ambiguous', null, 'expense'),
      record('new', '12.34', 'income')
    ];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (fail) throw PlatformException(code: 'unavailable');
      if (call.method == 'list') return jsonEncode(items);
      if (call.method == 'status') return <String, dynamic>{};
      return null;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));
  Future<void> show(WidgetTester tester, {bool hide = false}) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PaymentCaptureHomeCard(hideAmounts: hide))));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
      'home previews latest two with unresolved amounts and total count',
      (tester) async {
    await show(tester);
    expect(find.text('待确认收支 · 3 笔'), findsOneWidget);
    expect(find.text('¥12.34'), findsOneWidget);
    expect(find.text('金额待核对'), findsOneWidget);
    expect(find.text('¥8.00'), findsNothing);
    expect(find.text('查看全部 3 笔'), findsOneWidget);
    expect(find.text('尚未记入账本 · 核对后保存'), findsOneWidget);
  });
  testWidgets('home respects hidden amounts', (tester) async {
    await show(tester, hide: true);
    expect(find.text('••••'), findsNWidgets(2));
    expect(find.text('¥12.34'), findsNothing);
  });
  testWidgets('red packets show their income scene on the home screen',
      (tester) async {
    items.last['scene'] = 'wechat_redpacket';
    await show(tester);
    expect(find.text('收入 · 微信红包'), findsOneWidget);
    expect(find.text('¥12.34'), findsOneWidget);
  });
  testWidgets('foreground refresh reflects new native captures',
      (tester) async {
    await show(tester);
    items = [];
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('待确认收支 · 0 笔'), findsOneWidget);
    expect(find.text('暂无待确认，自动识别的收支会显示在这里'), findsOneWidget);
  });
  testWidgets('home opens dedicated inbox without permission switches',
      (tester) async {
    await show(tester);
    await tester.tap(find.text('查看全部 3 笔'));
    await tester.pumpAndSettle();
    expect(find.text('待确认收支'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.byTooltip('识别设置'), findsOneWidget);
  });
  testWidgets('read errors are retryable instead of claiming an empty inbox',
      (tester) async {
    fail = true;
    await show(tester);
    expect(find.text('待确认收支读取失败'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('待确认收支读取失败'));
    await tester.pumpAndSettle();
    expect(find.text('待确认收支 · 3 笔'), findsOneWidget);
  });
}
