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
import '../../../../core/providers/customer_wallet_providers.dart';
import '../../../../core/providers/business_settings_providers.dart';
import '../../../../core/services/customer_order_command_service.dart';
import 'services/order_confirmation_completion_service.dart';
import 'utils/order_form_data.dart';
import 'utils/order_form_validators.dart';
import 'widgets/order_confirmation_app_bar.dart';
import 'widgets/order_confirmation_content.dart';
import 'widgets/order_confirmation_submit_bar.dart';
import 'widgets/order_payment_pending_card.dart';
import 'controllers/order_confirmation_payment_controller.dart';
import 'controllers/order_confirmation_wallet_controller.dart';
import 'widgets/order_confirmation_wallet_card.dart';
import 'utils/order_form_submission.dart';
import 'utils/order_payment_strings.dart';
import 'utils/order_settings_review.dart';
import 'widgets/order_settings_changed_notice.dart';

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
  late final OrderConfirmationWalletController _wallet;
  late bool _useVnpay;
  int _latestSettingsRevision = 0;
  bool _settingsRejected = false;

  bool get _needsSettingsReview => requiresOrderSettingsReview(
    quotedRevision: widget.formData.settingsRevision,
    latestRevision: _latestSettingsRevision,
    paymentProtected: _payment.protectsSettings || _wallet.hasAttempt,
    rejectedByServer:
        _settingsRejected ||
        _payment.needsSettingsReview ||
        _wallet.needsSettingsReview,
  );

  void _reviewSettings() => context.pop(OrderConfirmationResult.reviewSettings);

  @override
  void initState() {
    super.initState();
    _useVnpay = widget.formData.paymentMethod == 'vnpay';
    _wallet = OrderConfirmationWalletController(
      service: ref.read(customerOrderPaymentServiceProvider),
      onCreated: (order) => _finishCreatedOrder(
        orderId: order.id,
        trackingCode: order.trackingCode,
        fallbackOrder: order,
        userId: order.customerId,
        addressTimestamp: order.createdAt,
      ),
    )..addListener(_onPaymentChanged);
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
    _wallet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final revision =
        ref.watch(businessSettingsProvider).valueOrNull?.revision ?? 0;
    if (revision > _latestSettingsRevision) _latestSettingsRevision = revision;
    final needsReview = _needsSettingsReview;
    final prepaid = widget.formData.deliveryFeePayer == DeliveryFeePayer.sender;
    final busy = _isSubmitting || _payment.isBusy || _wallet.isBusy;
    final walletPayment = prepaid && !_useVnpay;
    final walletSummary = walletPayment
        ? ref.watch(customerWalletSummaryProvider)
        : null;
    final canPayWallet =
        _wallet.hasAttempt ||
        (walletSummary?.asData?.value.availableBalance ?? -1) >=
            widget.formData.finance.customerServiceCharge;
    final session = _payment.session;
    final canEdit =
        !busy && !_payment.hasActiveSession && _wallet.canSwitchPayment;
    return PopScope(
      canPop: canEdit,
      child: Scaffold(
        backgroundColor: AppColors.bgLight,
        appBar: OrderConfirmationAppBar(
          canEdit: canEdit,
          onEdit: () => context.pop(),
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (needsReview) const OrderSettingsChangedNotice(),
            OrderConfirmationSubmitBar(
              isSubmitting: busy,
              onSubmit: needsReview ? _reviewSettings : _submitOrder,
              isEnabled: needsReview || !walletPayment || canPayWallet,
              idleLabel: needsReview
                  ? OrderSettingsChangedNotice.action
                  : !prepaid
                  ? OrderPaymentText.confirmOrder
                  : walletPayment
                  ? OrderPaymentText.walletSubmit
                  : _payment.hasActiveSession
                  ? OrderPaymentText.reopenPayment
                  : OrderPaymentText.payAndCreate,
              submittingLabel: 'Đang tạo đơn...',
            ),
          ],
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
              Expanded(
                child: OrderConfirmationContent(
                  data: widget.formData,
                  paymentDetails: prepaid
                      ? OrderConfirmationWalletCard(
                          deliveryFee:
                              widget.formData.finance.customerServiceCharge,
                          useVnpay: _useVnpay,
                          error: _wallet.error,
                          canSwitch:
                              !busy &&
                              !_payment.hasActiveSession &&
                              _wallet.canSwitchPayment,
                          onVnpaySelected: () =>
                              setState(() => _useVnpay = true),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitOrder() async {
    if (_isSubmitting || _payment.isBusy || _wallet.isBusy) return;
    if (_needsSettingsReview) {
      _reviewSettings();
      return;
    }
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

    final existing = _payment.orderSnapshot ?? _wallet.orderSnapshot;
    if (existing != null && (_payment.protectsSettings || _wallet.hasAttempt)) {
      await _submitPrepaidOrder(existing);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final data = widget.formData;
      // Check again before any new payment/order: reconnect messages can race
      // with submit. Issued sessions and uncertain wallet attempts bypass this.
      final current = await ref.read(businessSettingsServiceProvider).load();
      if (!mounted) return;
      if (current.revision > _latestSettingsRevision) {
        _latestSettingsRevision = current.revision;
      }
      if (_needsSettingsReview) return;
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
        await _submitPrepaidOrder(order);
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
        if (error is CustomerOrderCommandException &&
            error.needsSettingsReview) {
          _settingsRejected = true;
        }
        _showSnackBar('Không thể tạo đơn hàng: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitPrepaidOrder(OrderModel order) async {
    if (_useVnpay) {
      await _payment.submit(order.copyWith(paymentMethod: 'vnpay'));
      if (mounted && _payment.session == null && _payment.error != null) {
        _showSnackBar(_payment.error!, isError: true);
      }
    } else {
      await _wallet.submit(order.copyWith(paymentMethod: 'wallet'));
      if (mounted) ref.invalidate(customerWalletSummaryProvider);
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
    ref.invalidate(customerWalletSummaryProvider);
    ref.invalidate(customerWalletTransactionsProvider);

    if (!mounted) return;
    context.go(
      '/customer/create-order/success',
      extra: {
        'orderId': orderId,
        'trackingCode': trackingCode.isNotEmpty
            ? trackingCode
            : full.trackingCode,
        'deliveryFee': full.customerServiceCharge.toDouble(),
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
