import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/providers/customer_providers.dart';
import '../../../../core/utils/order_cargo_utils.dart';
import 'widgets/create_order_form_sections.dart';
import 'widgets/create_order_header.dart';
import 'widgets/create_order_summary.dart';
import 'widgets/submit_order_button.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderLayout {
  static const tabletBreakpoint = 600.0;
  static const desktopBreakpoint = 1024.0;
  static const tabletContentMaxWidth = 720.0;
  static const desktopContentMaxWidth = 760.0;

  const _CreateOrderLayout({
    required this.horizontalPadding,
    required this.maxContentWidth,
  });

  final double horizontalPadding;
  final double maxContentWidth;

  factory _CreateOrderLayout.fromWidth(double width) {
    if (width > desktopBreakpoint) {
      return const _CreateOrderLayout(
        horizontalPadding: AppSpacing.xl3,
        maxContentWidth: desktopContentMaxWidth,
      );
    }

    if (width >= tabletBreakpoint) {
      return const _CreateOrderLayout(
        horizontalPadding: AppSpacing.xl3,
        maxContentWidth: tabletContentMaxWidth,
      );
    }

    return const _CreateOrderLayout(
      horizontalPadding: AppSpacing.screenH,
      maxContentWidth: double.infinity,
    );
  }
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  static const _debugTag = '[CargoImagePickerDebug]';
  static const _defaultDeliveryFee = 30000.0;
  static const _paymentMethod = 'cash';

  final _formKey = GlobalKey<FormState>();
  final _pickupAddressController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _noteController = TextEditingController();
  final _itemNameController = TextEditingController();
  final _itemDescriptionController = TextEditingController();

  String _serviceType = 'standard';
  String _itemCategory = cargoCategories.first;
  XFile? _cargoImage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _pickupAddressController,
      _deliveryAddressController,
      _recipientNameController,
      _recipientPhoneController,
      _noteController,
      _itemNameController,
      _itemDescriptionController,
    ]) {
      controller.addListener(_refreshSummary);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _pickupAddressController,
      _deliveryAddressController,
      _recipientNameController,
      _recipientPhoneController,
      _noteController,
      _itemNameController,
      _itemDescriptionController,
    ]) {
      controller.removeListener(_refreshSummary);
      controller.dispose();
    }
    super.dispose();
  }

  void _refreshSummary() {
    if (mounted) setState(() {});
  }

  Future<void> _submitOrder() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showSnackBar('Vui lòng đăng nhập để tạo đơn hàng.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? itemImageUrl;
      final cargoImage = _cargoImage;
      if (cargoImage != null) {
        debugPrint(
          '$_debugTag before upload name=${cargoImage.name} path=${cargoImage.path}',
        );
        try {
          itemImageUrl = await ref
              .read(cargoImageServiceProvider)
              .uploadOrderCargoImage(userId: user.id, image: cargoImage);
          debugPrint('$_debugTag upload success url=$itemImageUrl');
        } catch (error) {
          debugPrint('$_debugTag upload failure error=$error');
          if (mounted) {
            _showSnackBar(
              'Không thể tải ảnh hàng hoá lên. Vui lòng chọn lại ảnh hoặc thử lại.',
              isError: true,
            );
          }
          rethrow;
        }
      }

      final now = DateTime.now();
      final order = OrderModel(
        id: '',
        customerId: user.id,
        driverId: null,
        status: 'pending',
        pickupAddress: _pickupAddressController.text.trim(),
        pickupLat: 0,
        pickupLng: 0,
        deliveryAddress: _deliveryAddressController.text.trim(),
        deliveryLat: 0,
        deliveryLng: 0,
        totalPrice: null,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        createdAt: now,
        trackingCode: '',
        estimatedPickupAt: null,
        estimatedDeliveryAt: null,
        actualPickedUpAt: null,
        actualDeliveredAt: null,
        cancelledAt: null,
        recipientName: _recipientNameController.text.trim(),
        recipientPhone: _recipientPhoneController.text.trim(),
        itemName: _itemNameController.text.trim(),
        itemCategory: _itemCategory,
        itemDescription: _itemDescriptionController.text.trim().isEmpty
            ? null
            : _itemDescriptionController.text.trim(),
        itemImageUrl: itemImageUrl,
        deliveryFee: _defaultDeliveryFee,
        serviceType: _serviceType,
        paymentMethod: _paymentMethod,
        statusNote: null,
        updatedAt: now,
      );

      final service = ref.read(customerOrderServiceProvider);
      await service.createOrder(order);

      ref.invalidate(customerOrdersProvider);
      ref.invalidate(recentOrdersProvider);
      ref.invalidate(activeOrderProvider);

      if (mounted) {
        _showSnackBar('Đơn hàng đã được tạo thành công.');
        context.pop();
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar('Không thể tạo đơn hàng: $error', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
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

  Future<void> _pickCargoImage() async {
    debugPrint('$_debugTag before opening picker');
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 82,
      );
      debugPrint('$_debugTag picker returned image=${image != null}');

      if (image == null) {
        debugPrint('$_debugTag picker returned null; user likely cancelled');
        return;
      }

      final size = await image.length();
      debugPrint(
        '$_debugTag picked file name=${image.name} path=${image.path} size=$size',
      );
      if (!mounted) return;
      setState(() => _cargoImage = image);
    } on PlatformException catch (error) {
      debugPrint(
        '$_debugTag picker platform failure code=${error.code} message=${error.message}',
      );
      if (!mounted) return;
      _showSnackBar(
        'Không thể mở thư viện ảnh. Vui lòng kiểm tra quyền truy cập ảnh.',
        isError: true,
      );
    } catch (error) {
      debugPrint('$_debugTag picker failure error=$error');
      if (!mounted) return;
      _showSnackBar('Không thể chọn ảnh. Vui lòng thử lại.', isError: true);
    }
  }

  void _removeCargoImage() {
    debugPrint('$_debugTag remove selected image');
    setState(() => _cargoImage = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        leadingWidth: 56,
        title: Text(
          'Tạo đơn giao hàng',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.headingMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.bgCard,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      bottomNavigationBar: SubmitOrderButton(
        isSubmitting: _isSubmitting,
        onPressed: _submitOrder,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = _CreateOrderLayout.fromWidth(constraints.maxWidth);

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      layout.horizontalPadding,
                      AppSpacing.lg,
                      layout.horizontalPadding,
                      AppSpacing.xl3,
                    ),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      const CreateOrderHeader(),
                      const SizedBox(height: AppSpacing.lg),
                      CreateOrderAddressSection(
                        pickupAddressController: _pickupAddressController,
                        deliveryAddressController: _deliveryAddressController,
                        requiredAddress: _requiredAddress,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      CreateOrderRecipientSection(
                        recipientNameController: _recipientNameController,
                        recipientPhoneController: _recipientPhoneController,
                        noteController: _noteController,
                        requiredText: _requiredText,
                        validatePhone: _validatePhone,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      CreateOrderCargoSection(
                        itemNameController: _itemNameController,
                        itemDescriptionController: _itemDescriptionController,
                        itemCategory: _itemCategory,
                        image: _cargoImage,
                        requiredText: _requiredText,
                        onCategoryChanged: (value) =>
                            setState(() => _itemCategory = value),
                        onPickImage: _pickCargoImage,
                        onRemoveImage: _removeCargoImage,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      CreateOrderServiceSection(
                        serviceType: _serviceType,
                        onChanged: (value) => setState(() {
                          _serviceType = value;
                        }),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const CreateOrderPaymentSection(),
                      const SizedBox(height: AppSpacing.lg),
                      const FeeSummary(deliveryFee: _defaultDeliveryFee),
                      const SizedBox(height: AppSpacing.lg),
                      CreateOrderConfirmationSection(
                        pickupAddress: _pickupAddressController.text,
                        deliveryAddress: _deliveryAddressController.text,
                        recipientName: _recipientNameController.text,
                        recipientPhone: _recipientPhoneController.text,
                        serviceType: _serviceType,
                        paymentMethod: _paymentMethod,
                        note: _noteController.text,
                        itemName: _itemNameController.text,
                        itemCategory: _itemCategory,
                        itemDescription: _itemDescriptionController.text,
                        itemImageName: _cargoImage?.name,
                        deliveryFee: _defaultDeliveryFee,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String? Function(String?) _requiredAddress(String message) {
    return (value) {
      if (value == null || value.trim().isEmpty) return message;
      if (value.trim().length < 6) {
        return 'Địa chỉ cần rõ hơn để tài xế có thể tìm thấy.';
      }
      return null;
    };
  }

  String? Function(String?) _requiredText(String message) {
    return (value) {
      if (value == null || value.trim().isEmpty) return message;
      return null;
    };
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return 'Vui lòng nhập số điện thoại người nhận.';
    if (phone.length < 9) return 'Số điện thoại chưa đủ chữ số.';
    return null;
  }
}
