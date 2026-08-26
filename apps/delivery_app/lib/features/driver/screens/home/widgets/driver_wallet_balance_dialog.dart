import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../driver_home_strings.dart';

enum DriverWalletBalanceAction { continueOnline, topUp }

Future<DriverWalletBalanceAction?> showDriverWalletBalanceDialog(
  BuildContext context, {
  required int availableBalance,
}) {
  return showDialog<DriverWalletBalanceAction>(
    context: context,
    barrierColor: AppColors.primary.withValues(alpha: 0.58),
    barrierDismissible: true,
    barrierLabel: DriverHomeStrings.walletCloseAction,
    builder: (_) =>
        DriverWalletBalanceDialog(availableBalance: availableBalance),
  );
}

class DriverWalletBalanceDialog extends StatelessWidget {
  const DriverWalletBalanceDialog({super.key, required this.availableBalance});

  final int availableBalance;

  @override
  Widget build(BuildContext context) {
    final isEmpty = availableBalance <= 0;
    final detail = isEmpty
        ? DriverHomeStrings.walletEmptyWarning
        : DriverHomeStrings.walletOfferHint;

    return Dialog(
      backgroundColor: AppColors.bgCard.withValues(alpha: 0),
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenH,
        vertical: AppSpacing.xl2,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Semantics(
            namesRoute: true,
            label:
                '${DriverHomeStrings.walletBalanceLabel} ${formatVnd(availableBalance)}',
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: AppRadius.xl2,
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadow.elevated,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _AccentRail(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl2,
                      AppSpacing.xl,
                      AppSpacing.xl2,
                      AppSpacing.xl2,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _OnlineBadge(),
                        const SizedBox(height: AppSpacing.lg),
                        const _WalletIcon(),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          DriverHomeStrings.onlineWalletTitle,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.headingLarge.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _BalancePanel(availableBalance: availableBalance),
                        const SizedBox(height: AppSpacing.lg),
                        _WalletHint(message: detail, isWarning: isEmpty),
                        const SizedBox(height: AppSpacing.xl2),
                        _WalletActions(isEmpty: isEmpty),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccentRail extends StatelessWidget {
  const _AccentRail();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: double.infinity,
      height: AppSpacing.xs,
      child: ColoredBox(color: AppColors.accent),
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: AppRadius.full,
        border: Border.all(color: AppColors.success.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            DriverHomeStrings.walletOnlineBadge,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletIcon extends StatelessWidget {
  const _WalletIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: AppRadius.xl,
        boxShadow: AppShadow.accentGlow,
      ),
      child: const Icon(
        Icons.account_balance_wallet_rounded,
        color: AppColors.accent,
        size: 34,
      ),
    );
  }
}

class _BalancePanel extends StatelessWidget {
  const _BalancePanel({required this.availableBalance});

  final int availableBalance;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.xl,
        boxShadow: AppShadow.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DriverHomeStrings.walletBalanceLabel,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textOnDark.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatVnd(availableBalance),
              style: AppTextStyles.displayMedium.copyWith(
                color: AppColors.textOnDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletHint extends StatelessWidget {
  const _WalletHint({required this.message, required this.isWarning});

  final String message;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? AppColors.warning : AppColors.info;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.md,
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning ? Icons.info_rounded : Icons.auto_awesome_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletActions extends StatelessWidget {
  const _WalletActions({required this.isEmpty});

  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    final primaryLabel = isEmpty
        ? DriverHomeStrings.walletTopUpNowAction
        : DriverHomeStrings.walletContinueAction;
    final primaryResult = isEmpty
        ? DriverWalletBalanceAction.topUp
        : DriverWalletBalanceAction.continueOnline;
    final secondaryLabel = isEmpty
        ? DriverHomeStrings.walletLaterAction
        : DriverHomeStrings.walletTopUpAction;
    final secondaryResult = isEmpty
        ? DriverWalletBalanceAction.continueOnline
        : DriverWalletBalanceAction.topUp;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          key: const ValueKey('wallet-primary-action'),
          width: double.infinity,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(primaryResult),
              icon: Icon(
                isEmpty ? Icons.add_card_rounded : Icons.check_rounded,
                size: 20,
              ),
              label: Text(primaryLabel, textAlign: TextAlign.center),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textOnAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                textStyle: AppTextStyles.labelLarge,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.full,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(secondaryResult),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                textStyle: AppTextStyles.labelMedium,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.full,
                ),
              ),
              child: Text(secondaryLabel, textAlign: TextAlign.center),
            ),
          ),
        ),
      ],
    );
  }
}
