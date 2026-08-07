import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../core/models/recent_address_model.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/providers/address_providers.dart';
import '../../../../core/providers/customer_providers.dart';
import 'utils/order_form_data.dart';
import 'widgets/order_confirmation_content.dart';
import 'widgets/order_confirmation_submit_bar.dart';

class OrderConfirmationScreen extends ConsumerStatefulWidget {
  const OrderConfirmationScreen({super.key, required this.formData});

  final OrderFormData formData;

  @override
  ConsumerState<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState
    extends ConsumerState<OrderConfirmationScreen> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: Text(
          'Xác nhận đơn',
          style: AppTextStyles.headingMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.bgLight,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: const BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: AppRadius.full,
            ),
            child: Text(
              '3 / 3',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton.icon(
            onPressed: _isSubmitting ? null : () => context.pop(),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Sửa'),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      bottomNavigationBar: OrderConfirmationSubmitBar(
        isSubmitting: _isSubmitting,
        onSubmit: _submitOrder,
      ),
      body: SafeArea(child: OrderConfirmationContent(data: widget.formData)),
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
        totalPrice: data.totalPrice,
        note: data.combinedDriverNote.isEmpty ? null : data.combinedDriverNote,
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
        itemDescription: data.itemDescription.trim().isEmpty
            ? null
            : data.itemDescription.trim(),
        itemImageUrl: itemImageUrl,
        deliveryFee: data.deliveryFee,
        serviceType: 'standard',
        paymentMethod: data.paymentMethod,
        statusNote: null,
        updatedAt: now,
      );

      final service = ref.read(customerOrderServiceProvider);
      final created = await service.createOrderWithTracking(order);
      try {
        await ref
            .read(recentAddressServiceProvider)
            .recordOrderAddresses(
              userId: user.id,
              pickup: RecentAddressModel(
                id: '',
                userId: user.id,
                addressType: RecentAddressType.pickup,
                formattedAddress: data.pickupFormattedAddress,
                addressDetail: data.pickupAddressDetail,
                deliveryNote: data.pickupDeliveryNote,
                latitude: data.pickupLat,
                longitude: data.pickupLng,
                usageCount: 1,
                lastUsedAt: now,
              ),
              delivery: RecentAddressModel(
                id: '',
                userId: user.id,
                addressType: RecentAddressType.delivery,
                formattedAddress: data.deliveryFormattedAddress,
                addressDetail: data.deliveryAddressDetail,
                deliveryNote: data.deliveryDeliveryNote,
                latitude: data.deliveryLat,
                longitude: data.deliveryLng,
                usageCount: 1,
                lastUsedAt: now,
              ),
            );
        ref.invalidate(recentAddressesProvider(user.id));
      } catch (error) {
        debugPrint(
          '[RecentAddress] record after order creation failed: $error',
        );
      }
      final full =
          await service.getOrderById(created.orderId) ??
          order.copyWith(
            id: created.orderId,
            trackingCode: created.trackingCode,
          );
      await service.notifyAfterOrderCreated(full);

      ref.invalidate(customerOrdersProvider);
      ref.invalidate(recentOrdersProvider);
      ref.invalidate(activeOrderProvider);

      if (mounted) {
        context.go(
          '/customer/create-order/success',
          extra: {
            'orderId': created.orderId,
            'trackingCode': created.trackingCode.isNotEmpty
                ? created.trackingCode
                : full.trackingCode,
            'deliveryFee': data.deliveryFee,
            'distanceKm': data.distanceKm,
          },
        );
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
