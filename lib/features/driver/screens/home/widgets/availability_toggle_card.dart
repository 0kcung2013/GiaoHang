import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/models/driver_model.dart';
import '../../../../../core/providers/customer_providers.dart';

/// Big toggle card: OFF (default) → ON to receive orders.
class AvailabilityToggleCard extends ConsumerStatefulWidget {
  final DriverModel driver;

  const AvailabilityToggleCard({super.key, required this.driver});

  @override
  ConsumerState<AvailabilityToggleCard> createState() =>
      _AvailabilityToggleCardState();
}

class _AvailabilityToggleCardState extends ConsumerState<AvailabilityToggleCard> {
  bool _isToggling = false;

  Future<void> _toggle(bool value) async {
    if (_isToggling) return;
    setState(() => _isToggling = true);
    try {
      await ref
          .read(driverServiceProvider)
          .updateAvailability(widget.driver.id, value);
      ref.invalidate(driverByUserIdProvider(widget.driver.userId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Không thể bật trạng thái. Thử lại.'
                  : 'Không thể tắt trạng thái. Thử lại.',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOn = widget.driver.isAvailable;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: isOn
            ? AppColors.success.withValues(alpha: 0.06)
            : AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(
          color: isOn
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.border,
        ),
        boxShadow: AppShadow.card,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isOn ? AppColors.success : AppColors.textMuted)
                  .withValues(alpha: 0.12),
              borderRadius: AppRadius.lg,
            ),
            child: Icon(
              isOn
                  ? Icons.radio_button_checked_rounded
                  : Icons.pause_circle_filled_rounded,
              color: isOn ? AppColors.success : AppColors.textMuted,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOn ? 'Đang sẵn sàng' : 'Đang offline',
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOn
                      ? 'Bạn đang nhận đơn mới'
                      : 'Bật để bắt đầu nhận đơn',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _isToggling
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.info,
                  ),
                )
              : Switch(
                  value: isOn,
                  onChanged: _toggle,
                  activeThumbColor: AppColors.success,
                  inactiveThumbColor: AppColors.textMuted,
                  inactiveTrackColor: AppColors.textMuted.withValues(alpha: 0.2),
                ),
        ],
      ),
    );
  }
}
