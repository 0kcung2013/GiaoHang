import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../../../core/mobile_app_role.dart';
import '../../../../../core/models/customer_wallet.dart';
import '../../../../help_center/screens/general_support_chat_screen.dart';
import '../../../../order_help/utils/order_help_ui.dart';
import '../constants/customer_account_strings.dart';

Future<void> showCustomerWalletTransactionSheet(
  BuildContext context,
  CustomerWalletTransaction transaction,
) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: AppColors.bgCard,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(transaction.label, style: AppTextStyles.headingMedium),
          const SizedBox(height: AppSpacing.lg),
          Text(
            formatVnd(transaction.amount),
            style: AppTextStyles.displayMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          SelectableText(transaction.id, style: AppTextStyles.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            OrderHelpUi.dateTime(transaction.createdAt),
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl2),
          FilledButton.icon(
            onPressed: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              navigator.push(
                MaterialPageRoute<void>(
                  builder: (_) => GeneralSupportChatScreen(
                    role: MobileAppRole.customer,
                    subject:
                        '${CustomerAccountStrings.refundRequestSubject} · ${transaction.id}',
                    contextMarker: '[GD:customer:${transaction.id}]',
                    initialBody:
                        '${transaction.label}\n${formatVnd(transaction.amount)}\n${OrderHelpUi.dateTime(transaction.createdAt)}\n',
                  ),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.textOnAccent,
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.support_agent_rounded),
            label: const Text(CustomerAccountStrings.walletSupport),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(CustomerAccountStrings.close),
          ),
        ],
      ),
    ),
  ),
);
