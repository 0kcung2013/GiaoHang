import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_storage/giaohang_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/models/order_finance.dart';
import '../../../../core/providers/address_providers.dart';
import '../../../../core/providers/customer_providers.dart';
import 'services/order_confirmation_completion_service.dart';
import 'utils/order_form_data.dart';
import 'utils/order_form_validators.dart';
import 'widgets/order_confirmation_app_bar.dart';
import 'widgets/order_confirmation_content.dart';
import 'widgets/order_confirmation_submit_bar.dart';
import 'widgets/order_payment_pending_card.dart';
import 'controllers/order_confirmation_payment_controller.dart';
import 'utils/order_form_submission.dart';
import 'utils/order_payment_strings.dart';

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
  late final OrderConfirmationPaymentController _payment;

  @override
  void initState() {
    super.initState();
    _payment = OrderConfirmationPaymentController(
      service: ref.read(customerOrderPaymentServiceProvider),
      onPaid: (session, order) async {
        if (!mounted) return;
        await _finishCreatedOrder(
          orderId: session.orderId!,
          trackingCode: session.trackingCode ?? '',
          fallbackOrder: order.copyWith(paymentStatus: OrderPaymentStatus.paid),
          userId: order.customerId,
          addressTimestamp: order.createdAt,
        );
      },
    )..addListener(_onPaymentChanged);
  }

  void _onPaymentChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _payment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prepaid = widget.formData.deliveryFeePayer == DeliveryFeePayer.sender;
    final busy = _isSubmitting || _payment.isBusy;
    final session = _payment.session;
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: OrderConfirmationAppBar(
        canEdit: !busy && !_payment.hasActiveSession,
        onEdit: () => context.pop(),
      ),
      bottomNavigationBar: OrderConfirmationSubmitBar(
        isSubmitting: busy,
        onSubmit: _submitOrder,
        idleLabel: !prepaid
            ? 'Xác nhận đặt đơn'
            : _payment.hasActiveSession
            ? OrderPaymentText.reopenPayment
            : OrderPaymentText.payAndCreate,
        submittingLabel: 'Đang tạo đơn...',
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (session != null)
              OrderPaymentPendingCard(
                amount: session.amount,
                expiresAt: session.expiresAt,
                onCheck: () => _payment.refresh(),
                isChecking: _payment.isChecking || busy,
                error: _payment.error,
              ),
            Expanded(child: OrderConfirmationContent(data: widget.formData)),
          ],
        ),
      ),
    );
  }

  Future<void> _submitOrder() async {
    if (_isSubmitting || _payment.isBusy) return;
    final data = widget.formData;
    final error = validateOrderDetails(
      recipientName: data.recipientName,
      recipientPhone: data.recipientPhone,
      itemName: data.itemName,
      itemCategory: data.itemCategory,
      hasPhoto: data.cargoImage != null,
    );
    if (error != null) {
      _showSnackBar(error, isError: true);
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showSnackBar('Vui lòng đăng nhập để tạo đơn hàng.', isError: true);
      return;
    }

    final existing = _payment.orderSnapshot;
    if (existing != null) {
      await _payment.submit(existing);
      if (mounted && _payment.session == null && _payment.error != null) {
        _showSnackBar(_payment.error!, isError: true);
      }
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
        } catch (error) {
          if (mounted) {
            _showSnackBar(_cargoImageUploadMessage(error), isError: true);
          }
          setState(() => _isSubmitting = false);
          return;
        }
      }

      final now = DateTime.now();
      final order = buildOrderFromForm(
        data: data,
        customerId: user.id,
        now: now,
        itemImageUrl: itemImageUrl,
      );

      if (order.deliveryFeePayer == DeliveryFeePayer.sender) {
        await _payment.submit(order);
        if (mounted && _payment.session == null && _payment.error != null) {
          _showSnackBar(_payment.error!, isError: true);
        }
        return;
      }

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

  String _cargoImageUploadMessage(Object error) {
    if (error is! R2MediaException) {
      return 'Không thể tải ảnh hàng hoá lên. Vui lòng thử lại.';
    }
    return switch (error.statusCode) {
      401 => 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      413 => 'Ảnh hàng hoá phải có dung lượng không quá 8 MB.',
      _ => 'Không thể tải ảnh hàng hoá lên R2: ${error.message}',
    };
  }
}
