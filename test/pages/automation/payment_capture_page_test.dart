import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/base_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/widgets/category/category_selector.dart';
import 'package:beecount/pages/automation/payment_capture_page.dart';
import 'package:beecount/pages/transaction/transaction_editor_page.dart';

class _CategoryRepository implements BaseRepository {
  final requestedKinds = <String>[];
  @override
  Future<List<Category>> getTopLevelCategories(String kind) async {
    requestedKinds.add(kind);
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.tntlikely.beecount/payment_capture');
  final calls = <String>[];
  var fail = false;
  String? kind;
  var pageEnabled = false;
  var ocrSupported = true;
  var ocrEnabled = false;
  var fixtureSource = 'notification';
  final enabledRequests = <Map<String, dynamic>>[];
  setUp(() {
    calls.clear();
    fail = false;
    kind = null;
    pageEnabled = false;
    ocrSupported = true;
    ocrEnabled = false;
    fixtureSource = 'notification';
    enabledRequests.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (fail) throw PlatformException(code: 'unavailable');
      if (call.method == 'status')
        return {
          'notification': false,
          'page': pageEnabled,
          'pageGranted': true,
          'ocrSupported': ocrSupported,
          'ocr': ocrEnabled
        };
      if (call.method == 'setEnabled') {
        final request = Map<String, dynamic>.from(call.arguments as Map);
        enabledRequests.add(request);
        if (request['source'] == 'ocr') ocrEnabled = request['enabled'] == true;
      }
      if (call.method == 'list')
        return jsonEncode([
          {
            'id': 'fixture',
            'package': 'com.tencent.mm',
            'source': fixtureSource,
            'time': 1700000000000,
            'amount': null,
            'merchant': null,
            'possibleDuplicate': true,
            'text': '支付成功，金额缺失（合成测试）',
            if (kind != null) 'kind': kind,
          }
        ]);
      return null;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  testWidgets('ambiguous captures stay pending and do not create transactions',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PaymentCapturePage()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('金额待核对'), 200);
    expect(find.text('金额待核对'), findsOneWidget);
    expect(find.textContaining('可能与另一条记录重复'), findsOneWidget);
    expect(calls, ['status', 'list']);
  });
  testWidgets('cancel consent does not enable capture or open settings',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PaymentCapturePage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(calls.contains('setEnabled'), isFalse);
    expect(calls.contains('notificationSettings'), isFalse);
  });
  testWidgets('native channel failure is visible and retryable',
      (tester) async {
    fail = true;
    await tester.pumpWidget(const MaterialApp(home: PaymentCapturePage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('读取失败'), findsOneWidget);
    fail = false;
    await tester.tap(find.byTooltip('刷新'));
    await tester.pumpAndSettle();
    expect(find.textContaining('读取失败'), findsNothing);
  });
  testWidgets('OCR is off and disabled until page reading is enabled',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PaymentCapturePage()));
    await tester.pumpAndSettle();
    final ocr = tester.widget<Switch>(find.byType(Switch).last);
    expect(ocr.value, isFalse);
    expect(ocr.onChanged, isNull);
    expect(enabledRequests, isEmpty);
  });
  testWidgets('unsupported Android cannot enable screenshot fallback',
      (tester) async {
    pageEnabled = true;
    ocrSupported = false;
    await tester.pumpWidget(const MaterialApp(home: PaymentCapturePage()));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch).last).onChanged, isNull);
  });
  for (final accept in [false, true]) {
    testWidgets(
        accept
            ? 'OCR consent enables only OCR without opening unrelated settings'
            : 'canceling screenshot consent keeps OCR off', (tester) async {
      pageEnabled = true;
      await tester.pumpWidget(const MaterialApp(home: PaymentCapturePage()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('本地截图文字识别兜底'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();
      expect(find.text('开启本地截图文字识别？'), findsOneWidget);
      await tester.tap(find.text(accept ? '同意并继续' : '取消'));
      await tester.pumpAndSettle();
      expect(
          enabledRequests,
          accept
              ? [
                  {'source': 'ocr', 'enabled': true}
                ]
              : isEmpty);
      expect(ocrEnabled, accept);
      expect(calls.contains('notificationSettings'), isFalse);
      expect(calls.contains('accessibilitySettings'), isFalse);
    });
  }
  for (final incoming in [true, false]) {
    testWidgets(
        incoming
            ? 'receipt review opens a single income tab and cancellation keeps the candidate'
            : 'legacy candidates without kind still open expense review',
        (tester) async {
      kind = incoming ? 'income' : null;
      fixtureSource = incoming ? 'page_ocr' : 'notification';
      final repo = _CategoryRepository();
      await tester.pumpWidget(ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('zh'),
          home: PaymentCapturePage(),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('核对并记账'), 200);
      expect(find.text(incoming ? '待确认收入 · 收款' : '待确认支出 · 付款'), findsOneWidget);
      await tester.ensureVisible(find.text('核对并记账'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('核对并记账'));
      await tester.pumpAndSettle();
      final editor = tester
          .widget<TransactionEditorPage>(find.byType(TransactionEditorPage));
      final expectedKind = incoming ? 'income' : 'expense';
      expect(editor.initialKind, expectedKind);
      expect(editor.creationSyncId, 'fixture');
      expect(editor.initialAmount, isNull);
      expect(
          tester.widget<CategorySelector>(find.byType(CategorySelector)).kind,
          expectedKind);
      expect(repo.requestedKinds, everyElement(expectedKind));
      final tabs = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabs.controller!.length, 1);
      expect(tabs.controller!.index, 0);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(calls.contains('remove'), isFalse);
      expect(find.byType(PaymentCapturePage), findsOneWidget);
    });
  }
}
