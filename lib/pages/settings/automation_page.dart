import 'dart:io';
import 'package:flutter/material.dart';
import '../automation/payment_capture_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/ui/ui.dart';
import '../../widgets/biz/biz.dart';
import '../../styles/tokens.dart';
import '../transaction/recurring_transaction_page.dart';
import '../settings/reminder_settings_page.dart';
import '../../l10n/app_localizations.dart';

/// 自动化功能二级页面
class AutomationPage extends ConsumerWidget {
  const AutomationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: AppLocalizations.of(context).automationPageTitle,
            subtitle: AppLocalizations.of(context).automationPageSubtitle,
            showBack: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      if (Platform.isAndroid) ...[
                        AppListTile(
                          leading: Icons.payments_outlined,
                          title: '支付自动识别（试验版）',
                          subtitle: '微信 / 支付宝付款、收款到账，自动捕获后确认收入或支出',
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const PaymentCapturePage(),
                          )),
                        ),
                        BeeTokens.cardDivider(context),
                      ],
                      // 周期记账
                      AppListTile(
                        leading: Icons.repeat,
                        title: AppLocalizations.of(context).mineRecurringTransactions,
                        subtitle: AppLocalizations.of(context).mineRecurringTransactionsSubtitle,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RecurringTransactionPage()),
                          );
                        },
                      ),
                      BeeTokens.cardDivider(context),
                      // 记账提醒
                      AppListTile(
                        leading: Icons.notifications_outlined,
                        title: AppLocalizations.of(context).mineReminderSettings,
                        subtitle: AppLocalizations.of(context).mineReminderSettingsSubtitle,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ReminderSettingsPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
