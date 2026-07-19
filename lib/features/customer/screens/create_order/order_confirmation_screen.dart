import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/models/order_model.dart';
import '../../../../../core/providers/customer_providers.dart';
import '../../../../../core/utils/order_cargo_utils.dart';
import 'utils/create_order_formatters.dart';
import 'utils/order_form_data.dart';

class OrderConfirmationScreen extends ConsumerStatefulWidget {
  final OrderFormData formData;

  const OrderConfirmationScreen({super.key, required this.formData});

  @override
  ConsumerState<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState
    extends ConsumerState<OrderConfirmationScreen> {
  static const _defaultDeliveryFee = 30000.0;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.formData;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text(
          'Xác nhận đơn hàng',
          style: AppTextStyles.headingMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.bgCard,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          TextButton.icon(
            onPressed: _isSubmitting ? null : () => context.pop(),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Sửa'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      bottomNavigationBar: _buildSubmitBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.lg,
            AppSpacing.screenH,
            AppSpacing.xl3,
          ),
          children: [
            _buildRouteCard(data),
            const SizedBox(height: AppSpacing.md),
            _buildRecipientCard(data),
            const SizedBox(height: AppSpacing.md),
            _buildCargoCard(data),
            const SizedBox(height: AppSpacing.md),
            _buildServicePaymentCard(data),
            const SizedBox(height: AppSpacing.md),
            _buildFeeCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        boxShadow: AppShadow.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: AppRadius.full,
            boxShadow: _isSubmitting ? null : AppShadow.accentGlow,
          ),
          child: Material(
            color: _isSubmitting
                ? AppColors.accent.withValues(alpha: 0.62)
                : AppColors.accent,
            borderRadius: AppRadius.full,
            child: InkWell(
              onTap: _isSubmitting ? null : _submitOrder,
              borderRadius: AppRadius.full,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isSubmitting
                          ? Icons.hourglass_empty_rounded
                          : Icons.check_circle_rounded,
                      color: AppColors.textOnAccent,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      _isSubmitting ? 'Đang tạo đơn...' : 'Xác nhận & Đặt đơn',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.textOnAccent,
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

  Widget _buildRouteCard(OrderFormData data) {
    final hasPickup = data.pickupAddress.isNotEmpty;
    final hasDelivery = data.deliveryAddress.isNotEmpty;

    return _Card(
      children: [
        _CardTitle(icon: Icons.alt_route_rounded, title: 'Lộ trình'),
        const SizedBox(height: AppSpacing.lg),
        _RouteStep(
          icon: Icons.my_location_rounded,
          iconColor: AppColors.info,
          label: 'Điểm lấy hàng',
          address: hasPickup ? data.pickupAddress : 'Chưa nhập',
          isEmpty: !hasPickup,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Container(
            width: 2,
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.info.withValues(alpha: 0.5),
                  AppColors.markerDrop.withValues(alpha: 0.5),
                ],
              ),
            ),
          ),
        ),
        _RouteStep(
          icon: Icons.location_on_rounded,
          iconColor: AppColors.markerDrop,
          label: 'Điểm giao hàng',
          address: hasDelivery ? data.deliveryAddress : 'Chưa nhập',
          isEmpty: !hasDelivery,
        ),
      ],
    );
  }

  Widget _buildRecipientCard(OrderFormData data) {
    return _Card(
      children: [
        _CardTitle(icon: Icons.person_rounded, title: 'Người nhận'),
        const SizedBox(height: AppSpacing.lg),
        _InfoRow(
          icon: Icons.badge_rounded,
          label: 'Tên',
          value: data.recipientName.isEmpty ? 'Chưa nhập' : data.recipientName,
        ),
        const SizedBox(height: AppSpacing.md),
        _InfoRow(
          icon: Icons.phone_rounded,
          label: 'SĐT',
          value: data.recipientPhone.isEmpty ? 'Chưa nhập' : data.recipientPhone,
        ),
        if (data.note.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _InfoRow(
            icon: Icons.sticky_note_2_rounded,
            label: 'Ghi chú',
            value: data.note,
          ),
        ],
      ],
    );
  }

  Widget _buildCargoCard(OrderFormData data) {
    return _Card(
      children: [
        _CardTitle(icon: Icons.inventory_2_rounded, title: 'Hàng hoá'),
        const SizedBox(height: AppSpacing.lg),
        _InfoRow(
          icon: Icons.inventory_2_outlined,
          label: 'Tên hàng',
          value: data.itemName.isEmpty ? 'Chưa nhập' : data.itemName,
        ),
        const SizedBox(height: AppSpacing.md),
        _InfoRow(
          icon: Icons.category_rounded,
          label: 'Loại',
          value: cargoCategoryLabel(data.itemCategory),
        ),
        if (data.itemDescription.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _InfoRow(
            icon: Icons.notes_rounded,
            label: 'Mô tả',
            value: data.itemDescription,
          ),
        ],
        if (data.cargoImage != null) ...[
          const SizedBox(height: AppSpacing.md),
          _InfoRow(
            icon: Icons.image_rounded,
            label: 'Ảnh',
            value: data.cargoImage!.name,
          ),
        ],
      ],
    );
  }

  Widget _buildServicePaymentCard(OrderFormData data) {
    return _Card(
      children: [
        _CardTitle(icon: Icons.settings_rounded, title: 'Dịch vụ & Thanh toán'),
        const SizedBox(height: AppSpacing.lg),
        _InfoRow(
          icon: Icons.local_shipping_rounded,
          label: 'Dịch vụ',
          value: serviceTypeLabel(data.serviceType),
        ),
        const SizedBox(height: AppSpacing.md),
        _InfoRow(
          icon: Icons.payments_rounded,
          label: 'Thanh toán',
          value: paymentMethodLabel(data.paymentMethod),
        ),
      ],
    );
  }

  Widget _buildFeeCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: AppRadius.md,
              boxShadow: AppShadow.subtle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
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
                  'Phí giao hàng tạm tính',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Phí sẽ được tính chính xác sau khi tài xế nhận đơn.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatDeliveryFee(_defaultDeliveryFee),
            style: AppTextStyles.headingSmall.copyWith(
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitOrder() async {
    if (_isSubmitting) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showSnackBar('Vui lòng đăng nhập để tạo đơn hàng.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final data = widget.formData;
      String? itemImageUrl;
      final cargoImage = data.cargoImage;
      if (cargoImage != null) {
        try {
          itemImageUrl = await ref
              .read(cargoImageServiceProvider)
              .uploadOrderCargoImage(userId: user.id, image: cargoImage);
        } catch (_) {
          if (mounted) {
            _showSnackBar(
              'Không thể tải ảnh hàng hoá lên. Vui lòng thử lại.',
              isError: true,
            );
          }
          setState(() => _isSubmitting = false);
          return;
        }
      }

      final now = DateTime.now();
      final order = OrderModel(
        id: '',
        customerId: user.id,
        driverId: null,
        status: 'pending',
        pickupAddress: data.pickupAddress.trim(),
        pickupLat: data.pickupLat,
        pickupLng: data.pickupLng,
        deliveryAddress: data.deliveryAddress.trim(),
        deliveryLat: data.deliveryLat,
        deliveryLng: data.deliveryLng,
        totalPrice: null,
        note: data.note.trim().isEmpty ? null : data.note.trim(),
        createdAt: now,
        trackingCode: '',
        estimatedPickupAt: null,
        estimatedDeliveryAt: null,
        actualPickedUpAt: null,
        actualDeliveredAt: null,
        cancelledAt: null,
        recipientName: data.recipientName.trim(),
        recipientPhone: data.recipientPhone.trim(),
        itemName: data.itemName.trim(),
        itemCategory: data.itemCategory,
        itemDescription:
            data.itemDescription.trim().isEmpty ? null : data.itemDescription.trim(),
        itemImageUrl: itemImageUrl,
        deliveryFee: _defaultDeliveryFee,
        serviceType: data.serviceType,
        paymentMethod: data.paymentMethod,
        statusNote: null,
        updatedAt: now,
      );

      final service = ref.read(customerOrderServiceProvider);
      final orderId = await service.createOrder(order);

      // Không auto-assign: đơn giữ status pending.
      // Thông báo in-app cho khách + tài xế gần nhất.
      final created =
          await service.getOrderById(orderId) ?? order.copyWith(id: orderId);
      await service.notifyAfterOrderCreated(created);

      ref.invalidate(customerOrdersProvider);
      ref.invalidate(recentOrdersProvider);
      ref.invalidate(activeOrderProvider);

      if (mounted) {
        _showSnackBar('Đơn hàng đã được tạo thành công.');
        context.pop();
        context.pop();
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar('Không thể tạo đơn hàng: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textOnAccent,
          ),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppSpacing.lg),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        boxShadow: AppShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _CardTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: AppRadius.sm,
          ),
          child: Icon(icon, color: AppColors.accent, size: 18),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          title,
          style: AppTextStyles.labelLarge.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _RouteStep extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String address;
  final bool isEmpty;

  const _RouteStep({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.address,
    required this.isEmpty,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: AppRadius.sm,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isEmpty ? AppColors.textMuted : AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.md),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
