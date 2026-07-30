import 'package:flutter/material.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/utils/order_cargo_utils.dart';
import '../utils/create_order_formatters.dart';
import '../utils/order_form_data.dart';
import 'confirmation_components.dart';
import 'delivery_quote_card.dart';

class OrderConfirmationContent extends StatelessWidget {
  const OrderConfirmationContent({super.key, required this.data});

  final OrderFormData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        AppSpacing.xl3,
      ),
      children: [
        const _ConfirmationIntro(),
        const SizedBox(height: AppSpacing.xl2),
        _RouteCard(data: data),
        const SizedBox(height: AppSpacing.md),
        DeliveryQuoteCard(data: data),
        const SizedBox(height: AppSpacing.xl3),
        _ContactsCard(data: data),
        const SizedBox(height: AppSpacing.xl3),
        _CargoCard(data: data),
        const SizedBox(height: AppSpacing.xl3),
        _PaymentCard(paymentMethod: data.paymentMethod),
      ],
    );
  }
}

class _ConfirmationIntro extends StatelessWidget {
  const _ConfirmationIntro();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: const BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: AppRadius.sm,
          ),
          child: Text(
            'BƯỚC 2 / 2',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.65,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Kiểm tra đơn hàng',
          style: AppTextStyles.displayMedium.copyWith(
            color: AppColors.textPrimary,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Xem lại thông tin và tổng phí trước khi gửi đơn đến tài xế.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.data});

  final OrderFormData data;

  @override
  Widget build(BuildContext context) {
    return ConfirmationCard(
      backgroundColor: AppColors.info.withValues(alpha: 0.06),
      borderColor: AppColors.info.withValues(alpha: 0.16),
      children: [
        const ConfirmationCardTitle(
          icon: Icons.alt_route_rounded,
          title: 'Lộ trình giao hàng',
          accentColor: AppColors.info,
        ),
        const SizedBox(height: AppSpacing.lg),
        ConfirmationRouteStep(
          icon: Icons.radio_button_checked_rounded,
          iconColor: AppColors.markerPickup,
          label: 'Lấy hàng',
          address: data.pickupAddress.isEmpty
              ? 'Chưa nhập'
              : data.pickupAddress,
          isEmpty: data.pickupAddress.isEmpty,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 17),
          child: Container(
            width: 2,
            height: 24,
            color: AppColors.info.withValues(alpha: 0.25),
          ),
        ),
        ConfirmationRouteStep(
          icon: Icons.location_on_rounded,
          iconColor: AppColors.markerDrop,
          label: 'Giao đến',
          address: data.deliveryAddress.isEmpty
              ? 'Chưa nhập'
              : data.deliveryAddress,
          isEmpty: data.deliveryAddress.isEmpty,
        ),
      ],
    );
  }
}

class _ContactsCard extends StatelessWidget {
  const _ContactsCard({required this.data});

  final OrderFormData data;

  @override
  Widget build(BuildContext context) {
    return ConfirmationCard(
      children: [
        const ConfirmationCardTitle(
          icon: Icons.people_outline_rounded,
          title: 'Liên hệ giao hàng',
          accentColor: AppColors.primary,
        ),
        const SizedBox(height: AppSpacing.lg),
        _ContactSummary(
          label: 'Người nhận',
          icon: Icons.person_outline_rounded,
          name: data.recipientName,
          phone: data.recipientPhone,
          note: data.note,
          accentColor: AppColors.primary,
          backgroundColor: AppColors.primary,
          primaryTextColor: AppColors.textOnDark,
          secondaryTextColor: AppColors.textOnDark,
          labelBackgroundColor: AppColors.accent,
        ),
        const SizedBox(height: AppSpacing.md),
        _ContactSummary(
          label: 'Người gửi',
          icon: Icons.account_circle_outlined,
          name: data.senderName,
          phone: data.senderPhone,
          accentColor: AppColors.info,
          backgroundColor: AppColors.info.withValues(alpha: 0.08),
          primaryTextColor: AppColors.textPrimary,
          secondaryTextColor: AppColors.textSecondary,
          labelBackgroundColor: AppColors.info.withValues(alpha: 0.15),
        ),
      ],
    );
  }
}

class _ContactSummary extends StatelessWidget {
  const _ContactSummary({
    required this.label,
    required this.icon,
    required this.name,
    required this.phone,
    required this.accentColor,
    required this.backgroundColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.labelBackgroundColor,
    this.note = '',
  });

  final String label;
  final IconData icon;
  final String name;
  final String phone;
  final Color accentColor;
  final Color backgroundColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color labelBackgroundColor;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadius.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: labelBackgroundColor,
                  borderRadius: AppRadius.md,
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: label == 'Người nhận'
                      ? AppColors.textOnAccent
                      : accentColor,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                label,
                style: AppTextStyles.labelLarge.copyWith(
                  color: primaryTextColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (label == 'Người nhận') ...[
                const Spacer(),
                Icon(
                  Icons.local_shipping_outlined,
                  color: AppColors.textOnDark.withValues(alpha: 0.75),
                  size: 20,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            name.isEmpty ? 'Chưa nhập' : name,
            style: AppTextStyles.headingSmall.copyWith(
              color: primaryTextColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            phone.isEmpty ? 'Chưa nhập số điện thoại' : phone,
            style: AppTextStyles.bodyMedium.copyWith(
              color: secondaryTextColor.withValues(alpha: 0.8),
            ),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.textOnDark.withValues(alpha: 0.1),
                borderRadius: AppRadius.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.notes_rounded,
                    size: 17,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      note,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textOnDark.withValues(alpha: 0.86),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CargoCard extends StatelessWidget {
  const _CargoCard({required this.data});

  final OrderFormData data;

  @override
  Widget build(BuildContext context) {
    return ConfirmationCard(
      children: [
        const ConfirmationCardTitle(
          icon: Icons.inventory_2_outlined,
          title: 'Kiện hàng',
          accentColor: AppColors.accent,
        ),
        const SizedBox(height: AppSpacing.lg),
        ConfirmationInfoRow(
          icon: Icons.inventory_2_outlined,
          label: 'Tên hàng',
          value: data.itemName.isEmpty ? 'Chưa nhập' : data.itemName,
        ),
        const SizedBox(height: AppSpacing.md),
        ConfirmationInfoRow(
          icon: Icons.category_outlined,
          label: 'Danh mục',
          value: cargoCategoryLabel(data.itemCategory),
        ),
        if (data.itemDescription.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          ConfirmationInfoRow(
            icon: Icons.subject_rounded,
            label: 'Mô tả',
            value: data.itemDescription,
          ),
        ],
        if (data.cargoImage != null) ...[
          const SizedBox(height: AppSpacing.md),
          ConfirmationInfoRow(
            icon: Icons.image_outlined,
            label: 'Ảnh đính kèm',
            value: data.cargoImage!.name,
          ),
        ],
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.paymentMethod});

  final String paymentMethod;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
        ),
      ),
      child: ConfirmationInfoRow(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Thanh toán',
        value: paymentMethodLabel(paymentMethod),
      ),
    );
  }
}
