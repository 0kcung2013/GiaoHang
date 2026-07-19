import 'package:flutter/material.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/order_model.dart';
import 'order_helpers.dart';

class OrderSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const OrderSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Tìm theo địa chỉ, mã đơn, người nhận...',
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textMuted,
        ),
        filled: true,
        fillColor: AppColors.bgCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.sm),
          child: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 22),
        ),
        prefixIconConstraints: const BoxConstraints(),
        suffixIcon: controller.text.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: InkWell(
                  onTap: () {
                    controller.clear();
                    onChanged('');
                  },
                  borderRadius: AppRadius.full,
                  child: const Icon(Icons.close_rounded,
                      color: AppColors.textMuted, size: 20),
                ),
              )
            : null,
        suffixIconConstraints: const BoxConstraints(),
        border: OutlineInputBorder(
          borderRadius: AppRadius.xl,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.xl,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.xl,
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }
}

class OrderFilterBar extends StatelessWidget {
  final List<String> filters;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const OrderFilterBar({
    super.key,
    required this.filters,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final active = selectedIndex == i;
          return Material(
            color: active ? AppColors.accent : AppColors.bgCard,
            borderRadius: AppRadius.full,
            elevation: active ? 0 : 0,
            shadowColor: Colors.transparent,
            child: InkWell(
              onTap: () => onSelected(i),
              borderRadius: AppRadius.full,
              splashColor: active
                  ? Colors.white.withValues(alpha: 0.15)
                  : AppColors.accent.withValues(alpha: 0.08),
              highlightColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm - 2,
                ),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.full,
                  boxShadow: active ? AppShadow.subtle : null,
                ),
                child: Text(
                  filters[i],
                  style: AppTextStyles.labelMedium.copyWith(
                    color: active
                        ? AppColors.textOnAccent
                        : AppColors.textSecondary,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const OrderCard({super.key, required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = OrderStatusView.fromStatus(order.status);
    final displayCode = order.trackingCode.isNotEmpty
        ? order.trackingCode
        : '#${order.id.substring(0, order.id.length >= 8 ? 8 : order.id.length)}';
    final price = order.totalPrice ?? order.deliveryFee;
    final priceText = price > 0 ? '${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}đ' : 'Chưa tính phí';

    return Material(
      color: AppColors.bgCard,
      borderRadius: AppRadius.xl,
      shadowColor: const Color(0x0A000000),
      elevation: 1.5,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.xl,
        splashColor: AppColors.accent.withValues(alpha: 0.06),
        highlightColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.xl,
            boxShadow: AppShadow.card,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildStatusDot(status),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _buildContent(status, displayCode, priceText)),
              const SizedBox(width: AppSpacing.sm),
              _buildChevron(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusDot(OrderStatusView status) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(right: AppSpacing.xs),
      decoration: BoxDecoration(
        color: status.color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: status.color.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    OrderStatusView status,
    String displayCode,
    String priceText,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                order.deliveryAddress,
                style: AppTextStyles.headingSmall.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _StatusPill(label: status.label, color: status.color),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Text(
              displayCode,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 0,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Container(
                width: 3,
                height: 3,
                decoration: const BoxDecoration(
                  color: AppColors.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Text(
              timeAgo(order.createdAt),
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 0,
              ),
            ),
            const Spacer(),
            Text(
              priceText,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChevron() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.sm,
      ),
      child: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted,
        size: 20,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.full,
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0,
          height: 1.2,
        ),
      ),
    );
  }
}

String timeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inSeconds < 60) return 'Vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes}p';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays} ngày';
  return '${(diff.inDays / 7).floor()} tuần';
}

// ── States ────────────────────────────────────────────────────────────────────

class OrderShimmer extends StatelessWidget {
  const OrderShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        0,
        AppSpacing.screenH,
        AppSpacing.xl2,
      ),
      itemCount: 5,
      itemBuilder: (_, _) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: _ShimmerCard(),
      ),
    );
  }
}

class _ShimmerCard extends StatefulWidget {
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.25, end: 0.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final c = AppColors.border.withValues(alpha: _anim.value);
        return Container(
          height: 72,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: AppRadius.xl,
            boxShadow: AppShadow.card,
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 200,
                      height: 14,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: AppRadius.sm,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      width: 120,
                      height: 10,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: AppRadius.sm,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class OrderEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const OrderEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl2,
          vertical: AppSpacing.xl4,
        ),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl,
          boxShadow: AppShadow.card,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: AppRadius.full,
              ),
              child: Icon(icon, color: AppColors.accent, size: 28),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrderErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const OrderErrorState({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl2,
          vertical: AppSpacing.xl4,
        ),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl,
          boxShadow: AppShadow.card,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: AppRadius.full,
              ),
              child: const Icon(Icons.signal_wifi_off_rounded,
                  color: AppColors.error, size: 28),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Không tải được đơn hàng',
              textAlign: TextAlign.center,
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Vui lòng kiểm tra kết nối và thử lại.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Material(
              color: AppColors.accent,
              borderRadius: AppRadius.full,
              child: InkWell(
                onTap: onRetry,
                borderRadius: AppRadius.full,
                splashColor: Colors.white.withValues(alpha: 0.15),
                highlightColor: Colors.white.withValues(alpha: 0.05),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl2,
                    vertical: AppSpacing.md,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded,
                          color: AppColors.textOnAccent, size: 18),
                      SizedBox(width: AppSpacing.sm),
                      Text('Thử lại',
                          style: TextStyle(color: AppColors.textOnAccent)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrderLoginRequired extends StatelessWidget {
  const OrderLoginRequired({super.key});

  @override
  Widget build(BuildContext context) {
    return const OrderEmptyState(
      icon: Icons.lock_outline_rounded,
      title: 'Cần đăng nhập',
      message: 'Vui lòng đăng nhập để xem đơn hàng của bạn.',
    );
  }
}
