import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/pages/automation/payment_capture_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.tntlikely.beecount/payment_capture');
  final calls = <String>[];
  var fail = false;
  setUp(() {
    calls.clear();
    fail = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (fail) throw PlatformException(code: 'unavailable');
      if (call.method == 'status') return {'notification': false, 'page': false};
      if (call.method == 'list') return jsonEncode([{
        'id': 'fixture', 'package': 'com.tencent.mm', 'source': 'notification',
        'time': 1700000000000, 'amount': null, 'merchant': null,
        'possibleDuplicate': true, 'text': '支付成功，金额缺失（合成测试）',
      }]);
      return null;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  testWidgets('ambiguous captures stay pending and do not create transactions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PaymentCapturePage()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('金额待核对'), 200);
    expect(find.text('金额待核对'), findsOneWidget);
    expect(find.textContaining('可能与另一条记录重复'), findsOneWidget);
    expect(calls, ['status', 'list']);
  });
  testWidgets('cancel consent does not enable capture or open settings', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PaymentCapturePage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(calls.contains('setEnabled'), isFalse);
    expect(calls.contains('notificationSettings'), isFalse);
  });
  testWidgets('native channel failure is visible and retryable', (tester) async {
    fail = true;
    await tester.pumpWidget(const MaterialApp(home: PaymentCapturePage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('读取失败'), findsOneWidget);
    fail = false;
    await tester.tap(find.byTooltip('刷新'));
    await tester.pumpAndSettle();
    expect(find.textContaining('读取失败'), findsNothing);
  });
}
