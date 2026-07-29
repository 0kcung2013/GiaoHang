part of 'dashboard_hero.dart';

class _HeroSurface extends StatelessWidget {
  final Widget child;

  const _HeroSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl2),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.xl2,
        boxShadow: const [
          BoxShadow(
            color: Color(0x122C211B),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Eyebrow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Eyebrow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.accent, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryHeroButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PrimaryHeroButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.accent,
        borderRadius: AppRadius.lg,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.textPrimary.withValues(alpha: 0.1),
          child: SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.textPrimary, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyRouteCue extends StatelessWidget {
  const _EmptyRouteCue();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.lg,
      ),
      child: const Column(
        children: [
          _RouteCueRow(
            icon: Icons.radio_button_checked_rounded,
            label: 'Điểm lấy hàng',
            color: AppColors.textPrimary,
          ),
          Padding(
            padding: EdgeInsets.only(left: 9),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                height: 16,
                child: VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.border,
                ),
              ),
            ),
          ),
          _RouteCueRow(
            icon: Icons.location_on_rounded,
            label: 'Chọn điểm giao',
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  final OrderModel order;

  const _RouteSummary({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.lg,
      ),
      child: Column(
        children: [
          _RouteCueRow(
            icon: Icons.radio_button_checked_rounded,
            label: order.pickupAddress,
            color: AppColors.textPrimary,
          ),
          const Padding(
            padding: EdgeInsets.only(left: 9),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                height: 16,
                child: VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.border,
                ),
              ),
            ),
          ),
          _RouteCueRow(
            icon: Icons.location_on_rounded,
            label: order.deliveryAddress,
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

class _RouteCueRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _RouteCueRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _DeliveryProgress extends StatelessWidget {
  final String status;

  const _DeliveryProgress({required this.status});

  @override
  Widget build(BuildContext context) {
    final activeIndex = _progressIndex(status);
    const labels = ['Xác nhận', 'Lấy hàng', 'Đang giao', 'Hoàn thành'];

    return Column(
      children: [
        Row(
          children: List.generate(labels.length, (index) {
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(
                  right: index == labels.length - 1 ? 0 : AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: index <= activeIndex
                      ? AppColors.accent
                      : AppColors.border,
                  borderRadius: AppRadius.full,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: List.generate(labels.length, (index) {
            return Expanded(
              child: Text(
                labels[index],
                textAlign: index == 0
                    ? TextAlign.left
                    : index == labels.length - 1
                    ? TextAlign.right
                    : TextAlign.center,
                style: AppTextStyles.labelSmall.copyWith(
                  color: index == activeIndex
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: index == activeIndex
                      ? FontWeight.w700
                      : FontWeight.w500,
                  fontSize: 10,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _DriverSummary extends StatelessWidget {
  final DriverModel? driver;
  final bool hasDriver;
  final bool compact;

  const _DriverSummary({
    required this.driver,
    required this.hasDriver,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = driver?.fullName?.trim();
    final vehicle = driver?.vehicleSummary.trim();

    return Row(
      children: [
        Container(
          width: compact ? 40 : 44,
          height: compact ? 40 : 44,
          decoration: BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: AppRadius.md,
          ),
          child: Icon(
            hasDriver ? Icons.person_rounded : Icons.person_search_rounded,
            color: AppColors.accent,
            size: 22,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name?.isNotEmpty == true
                    ? name!
                    : hasDriver
                    ? 'Đang tải thông tin tài xế'
                    : 'Đang tìm tài xế phù hợp',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (vehicle?.isNotEmpty == true) ...[
                const SizedBox(height: 2),
                Text(
                  [
                    vehicle!,
                    if (driver?.licensePlate?.trim().isNotEmpty == true)
                      driver!.licensePlate!.trim(),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (driver?.rating != null) ...[
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
          const SizedBox(width: 2),
          Text(
            driver!.rating!.toStringAsFixed(1),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}
