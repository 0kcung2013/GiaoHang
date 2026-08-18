import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/models/order_finance.dart';
import '../../../../core/providers/address_providers.dart';
import '../../../../core/providers/customer_providers.dart';
import 'services/order_confirmation_completion_service.dart';
import 'utils/order_form_data.dart';
import 'widgets/order_confirmation_app_bar.dart';
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
      appBar: OrderConfirmationAppBar(
        canEdit: !_isSubmitting,
        onEdit: () => context.pop(),
      ),
      bottomNavigationBar: OrderConfirmationSubmitBar(
        isSubmitting: _isSubmitting,
        onSubmit: _submitOrder,
        idleLabel: 'Xác nhận đặt đơn',
        submittingLabel: 'Đang tạo đơn...',
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
        totalPrice: data.finance.totalPrice.toDouble(),
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
        paymentMode: data.paymentMode,
        deliveryFeePayer: data.deliveryFeePayer,
        paymentStatus: OrderPaymentStatus.notRequired,
        goodsValue: data.goodsValue,
        codCollectionAmount: data.codCollectionAmount,
        platformFeeRateBps: 0,
        platformFeeAmount: 0,
        driverNetEarning: data.finance.driverNetEarning,
        driverAdvanceAmount: data.finance.driverAdvanceAmount,
        receiverCollectionAmount: data.finance.receiverCollectionAmount,
        statusNote: null,
        updatedAt: now,
      );

      final service = ref.read(customerOrderServiceProvider);
      final created = await service.createOrderWithTracking(order);
      await _finishCreatedOrder(
        orderId: created.orderId,
        trackingCode: created.trackingCode,
        fallbackOrder: order,
        userId: user.id,
        addressTimestamp: now,
      );
    } catch (error) {
      if (mounted) {
        _showSnackBar('Không thể tạo đơn hàng: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _finishCreatedOrder({
    required String orderId,
    required String trackingCode,
    required OrderModel fallbackOrder,
    required String userId,
    required DateTime addressTimestamp,
  }) async {
    final service = ref.read(customerOrderServiceProvider);
    final full =
        await OrderConfirmationCompletionService(
          orderService: service,
          recentAddressService: ref.read(recentAddressServiceProvider),
        ).complete(
          orderId: orderId,
          trackingCode: trackingCode,
          fallbackOrder: fallbackOrder,
          data: widget.formData,
          userId: userId,
          addressTimestamp: addressTimestamp,
        );
    ref.invalidate(recentAddressesProvider(userId));
    ref.invalidate(customerOrdersProvider);
    ref.invalidate(recentOrdersProvider);
    ref.invalidate(activeOrderProvider);

    if (!mounted) return;
    context.go(
      '/customer/create-order/success',
      extra: {
        'orderId': orderId,
        'trackingCode': trackingCode.isNotEmpty
            ? trackingCode
            : full.trackingCode,
        'deliveryFee': widget.formData.deliveryFee,
        'distanceKm': widget.formData.distanceKm,
      },
    );
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
