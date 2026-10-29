import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../providers/business_settings_providers.dart';
import '../utils/platform_fee_strings.dart';

abstract final class PlatformFeeStrings {
  static const title = 'Phí sàn';
  static const unavailable = 'Chưa tải được phí sàn';
  static const retry = 'Thử lại';
  static const unclassified = 'Hoàn thiện loại khách hàng để xem phí sàn';
}

class PlatformFeeCard extends ConsumerWidget {
  const PlatformFeeCard({super.key, this.driver = false, this.customerType});
  final bool driver;
  final String? customerType;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: AppRadius.lg,
      border: Border.all(color: AppColors.border),
    ),
    child: !driver && customerType == null
        ? Text(PlatformFeeStrings.unclassified, style: AppTextStyles.bodySmall)
        : ref
              .watch(businessSettingsProvider)
              .when(
                skipError: false,
                loading: () =>
                    const LinearProgressIndicator(color: AppColors.accent),
                error: (_, _) => Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(PlatformFeeStrings.unavailable),
                    TextButton(
                      onPressed: () => ref.invalidate(businessSettingsProvider),
                      child: const Text(PlatformFeeStrings.retry),
                    ),
                  ],
                ),
                data: (settings) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.percent_rounded,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            PlatformFeeStrings.title,
                            style: AppTextStyles.labelLarge,
                          ),
                        ),
                        Text(
                          BusinessSettings.formatFeePercent(
                            driver
                                ? settings.driverPlatformFeeBps
                                : settings.customerPlatformFeeBps(
                                    customerType!,
                                  ),
                          ),
                          style: AppTextStyles.headingMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      driver
                          ? PlatformFeeText.driverHint
                          : PlatformFeeText.customerHint,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
  );
}
