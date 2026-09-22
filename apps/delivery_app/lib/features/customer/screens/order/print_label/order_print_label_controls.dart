import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import 'order_print_label_strings.dart';

const orderPrintLabelCopiesKey = Key('order-print-label-copies');
const orderPrintLabelButtonKey = Key('order-print-label-button');

class OrderPrintLabelHeader extends StatelessWidget {
  const OrderPrintLabelHeader({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: AppRadius.md,
          ),
          child: const Icon(
            Icons.print_rounded,
            color: AppColors.accent,
            size: 22,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            OrderPrintLabelStrings.screenTitle,
            style: AppTextStyles.headingMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          onPressed: onClose,
          tooltip: OrderPrintLabelStrings.close,
          icon: const Icon(Icons.close_rounded),
          color: AppColors.textSecondary,
        ),
      ],
    );
  }
}

class OrderPrintLabelDemoNotice extends StatelessWidget {
  const OrderPrintLabelDemoNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: const BoxDecoration(
              color: AppColors.accent,
              borderRadius: AppRadius.full,
            ),
            child: Text(
              OrderPrintLabelStrings.demoBadge,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textOnAccent,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              OrderPrintLabelStrings.demoNotice,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OrderPrintLabelSettings extends StatelessWidget {
  const OrderPrintLabelSettings({
    super.key,
    required this.copies,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int copies;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            OrderPrintLabelStrings.printSettings,
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const _SettingIcon(icon: Icons.straighten_rounded),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: _SettingText(
                  label: OrderPrintLabelStrings.paperSize,
                  value: OrderPrintLabelStrings.paperSizeValue,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const _SettingIcon(icon: Icons.content_copy_rounded),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    OrderPrintLabelStrings.copies,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    key: orderPrintLabelCopiesKey,
                    decoration: BoxDecoration(
                      color: AppColors.bgLight,
                      borderRadius: AppRadius.full,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CopyButton(
                          icon: Icons.remove_rounded,
                          tooltip: OrderPrintLabelStrings.decreaseCopies,
                          onTap: onDecrease,
                        ),
                        SizedBox(
                          width: 28,
                          child: Text(
                            '$copies',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _CopyButton(
                          icon: Icons.add_rounded,
                          tooltip: OrderPrintLabelStrings.increaseCopies,
                          onTap: onIncrease,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingIcon extends StatelessWidget {
  const _SettingIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: AppRadius.md,
      ),
      child: Icon(icon, color: AppColors.accent, size: 19),
    );
  }
}

class _SettingText extends StatelessWidget {
  const _SettingText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.full,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              icon,
              size: 19,
              color: onTap == null
                  ? AppColors.textMuted
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class OrderPrintLabelActionBar extends StatelessWidget {
  const OrderPrintLabelActionBar({
    super.key,
    required this.copies,
    required this.isPrinting,
    required this.hasPrinted,
    required this.onPrint,
  });

  final int copies;
  final bool isPrinting;
  final bool hasPrinted;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final label = isPrinting
        ? OrderPrintLabelStrings.printingAction
        : hasPrinted
        ? OrderPrintLabelStrings.printedAction
        : '${OrderPrintLabelStrings.printAction} · $copies bản';
    final icon = hasPrinted ? Icons.check_circle_rounded : Icons.print_rounded;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.md,
          AppSpacing.screenH,
          AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Semantics(
          button: true,
          label: label,
          child: Container(
            key: orderPrintLabelButtonKey,
            height: 54,
            decoration: BoxDecoration(
              color: hasPrinted ? AppColors.success : AppColors.accent,
              borderRadius: AppRadius.full,
              boxShadow: hasPrinted ? AppShadow.subtle : AppShadow.accentGlow,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: AppRadius.full,
              child: InkWell(
                onTap: isPrinting ? null : onPrint,
                borderRadius: AppRadius.full,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: AppColors.textOnAccent, size: 21),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textOnAccent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OrderPrintLabelSheetHandle extends StatelessWidget {
  const OrderPrintLabelSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: AppRadius.full,
        ),
      ),
    );
  }
}
