import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../../../../../core/location/driver_location_producer_policy.dart';
import '../../../../../core/providers/customer_providers.dart';
import '../../../../../core/providers/driver_wallet_providers.dart';
import '../../../../../core/providers/location_providers.dart';
import '../driver_home_strings.dart';
import 'driver_wallet_balance_dialog.dart';

bool shouldShowOnlineWalletNotice(String? offeredOrderId) {
  return offeredOrderId == null || offeredOrderId.trim().isEmpty;
}

/// Trạng thái online là ý định nhận đơn; trạng thái busy được suy ra từ đơn active.
class AvailabilityToggleCard extends ConsumerStatefulWidget {
  const AvailabilityToggleCard({
    super.key,
    required this.driver,
    required this.hasActiveOrder,
  });

  final DriverModel driver;
  final bool hasActiveOrder;

  @override
  ConsumerState<AvailabilityToggleCard> createState() =>
      _AvailabilityToggleCardState();
}

class _AvailabilityToggleCardState
    extends ConsumerState<AvailabilityToggleCard> {
  bool _isToggling = false;

  Future<void> _toggle(bool value) async {
    if (_isToggling) return;
    setState(() => _isToggling = true);

    try {
      String? offeredOrderId;
      if (value) {
        final position = await ref
            .read(locationServiceProvider)
            .getCurrentPosition();
        if (position == null) {
          throw Exception(
            'Hãy bật GPS và cấp quyền vị trí trước khi nhận đơn.',
          );
        }

        final locationMode = ref.read(driverLocationModeProvider);
        offeredOrderId = await ref
            .read(driverServiceProvider)
            .setOnlineWithLocation(
              driverProfileId: widget.driver.id,
              lat: position.latitude,
              lng: position.longitude,
              heading: position.heading,
              speed: position.speed,
              coordinateSpace: locationMode.rawGpsCoordinateSpace,
            );
        ref.invalidate(currentPositionProvider);
        ref.invalidate(availableOrdersProvider(widget.driver.userId));
      } else {
        await ref.read(driverServiceProvider).updateAvailability(false);
      }

      ref.invalidate(driverByUserIdProvider(widget.driver.userId));
      if (mounted) setState(() => _isToggling = false);

      if (value && shouldShowOnlineWalletNotice(offeredOrderId)) {
        await _showOnlineWalletNotice();
      }
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isEmpty
                ? 'Không thể cập nhật trạng thái. Vui lòng thử lại.'
                : message,
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted && _isToggling) setState(() => _isToggling = false);
    }
  }

  Future<void> _showOnlineWalletNotice() async {
    try {
      final wallet = await ref.read(driverWalletServiceProvider).getSummary();
      ref.invalidate(driverWalletSummaryProvider);
      if (!mounted) return;

      final action = await showDriverWalletBalanceDialog(
        context,
        availableBalance: wallet.availableBalance,
      );
      if (mounted && action == DriverWalletBalanceAction.topUp) {
        context.go('/driver-home?tab=earnings');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(DriverHomeStrings.walletUnavailable),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = widget.driver.isAvailable;
    final isBusy = widget.hasActiveOrder;
    final statusLabel = isBusy
        ? DriverHomeStrings.activityBusy
        : isOnline
        ? DriverHomeStrings.activityOnline
        : DriverHomeStrings.activityOffline;
    final statusColor = isBusy
        ? AppColors.warning
        : isOnline
        ? AppColors.accent
        : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl,
        border: Border.all(
          color: isOnline || isBusy
              ? AppColors.accent.withValues(alpha: 0.22)
              : AppColors.border,
        ),
        boxShadow: AppShadow.subtle,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DriverHomeStrings.activityLabel,
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        statusLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          AnimatedSwitcher(
            duration: AppDuration.normal,
            child: _isToggling
                ? Semantics(
                    label: DriverHomeStrings.activityUpdating,
                    child: const SizedBox(
                      key: ValueKey('syncing'),
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Icon(
                          Icons.sync_rounded,
                          color: AppColors.accent,
                          size: 24,
                        ),
                      ),
                    ),
                  )
                : Semantics(
                    label: DriverHomeStrings.activityToggleLabel,
                    value: statusLabel,
                    child: Switch(
                      key: const ValueKey('switch'),
                      value: isOnline,
                      onChanged: _toggle,
                      activeThumbColor: AppColors.textOnAccent,
                      activeTrackColor: AppColors.accent,
                      inactiveThumbColor: AppColors.bgCard,
                      inactiveTrackColor: AppColors.textMuted.withValues(
                        alpha: 0.35,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
