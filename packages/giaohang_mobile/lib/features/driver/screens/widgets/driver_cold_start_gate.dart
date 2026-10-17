import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../providers/driver_cold_start_availability.dart';
import '../home/driver_home_strings.dart';
import '../home/widgets/driver_state_widgets.dart';

class DriverColdStartGate extends ConsumerWidget {
  const DriverColdStartGate({
    super.key,
    required this.userId,
    required this.child,
  });

  final String userId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reset = ref.watch(driverColdStartAvailabilityProvider(userId));

    return reset.when(
      data: (_) => child,
      loading: () => const _ColdStartLoadingState(),
      error: (_, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        child: Center(
          child: DriverMessageState(
            icon: Icons.cloud_off_rounded,
            title: DriverHomeStrings.coldStartErrorTitle,
            message: DriverHomeStrings.coldStartErrorMessage,
            actionLabel: DriverHomeStrings.retryAction,
            onAction: () =>
                ref.invalidate(driverColdStartAvailabilityProvider(userId)),
            color: AppColors.error,
          ),
        ),
      ),
    );
  }
}

class _ColdStartLoadingState extends StatelessWidget {
  const _ColdStartLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: DriverHomeStrings.coldStartLoadingSemantic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: AppRadius.xl,
              ),
              child: const Icon(
                Icons.power_settings_new_rounded,
                color: AppColors.accent,
                size: 30,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              DriverHomeStrings.coldStartLoading,
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
