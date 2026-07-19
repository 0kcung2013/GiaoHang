import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../../core/providers/location_providers.dart';
import '../../../../core/utils/order_cargo_utils.dart';
import 'utils/order_form_data.dart';
import 'widgets/create_order_form_sections.dart';
import 'widgets/create_order_header.dart';
import 'widgets/map_picker_sheet.dart';
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

  double _pickupLat = 0;
  double _pickupLng = 0;
  double _deliveryLat = 0;
  double _deliveryLng = 0;

  Position? _currentPosition;
  bool _isLoadingPosition = false;

  @override
  void initState() {
    super.initState();
    _preloadCurrentPosition();
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
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _preloadCurrentPosition() async {
    if (_isLoadingPosition) return;
    _isLoadingPosition = true;
    try {
      _currentPosition = await Geolocator.getLastKnownPosition();
      _currentPosition ??=
          await ref.read(locationServiceProvider).getCurrentPosition();
    } catch (_) {
      _currentPosition = null;
    } finally {
      _isLoadingPosition = false;
    }
  }

  Future<void> _openMapPicker(String type) async {
    LatLng initialPos;
    if (type == 'pickup' && _pickupLat != 0) {
      initialPos = LatLng(_pickupLat, _pickupLng);
    } else if (type == 'delivery' && _deliveryLat != 0) {
      initialPos = LatLng(_deliveryLat, _deliveryLng);
    } else {
      Position? pos = _currentPosition;
      pos ??= await ref.read(locationServiceProvider).getCurrentPosition();
      if (pos != null) {
        initialPos = LatLng(pos.latitude, pos.longitude);
        _currentPosition = pos;
      } else {
        _showSnackBar(
          'Không thể định vị vị trí hiện tại. Vui lòng chọn vị trí trên bản đồ.',
          isError: true,
        );
        initialPos = const LatLng(10.762622, 106.660172);
      }
    }

    final result = await showModalBottomSheet<MapPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MapPickerSheet(initialPosition: initialPos),
    );

    if (result == null || !mounted) return;

    final address = result.address;
    final lat = result.position.latitude;
    final lng = result.position.longitude;

    setState(() {
      if (type == 'pickup') {
        _pickupLat = lat;
        _pickupLng = lng;
        _pickupAddressController.text = address;
      } else {
        _deliveryLat = lat;
        _deliveryLng = lng;
        _deliveryAddressController.text = address;
      }
    });
  }

  void _goToConfirmation() {
    if (!_formKey.currentState!.validate()) return;

    final formData = OrderFormData(
      pickupAddress: _pickupAddressController.text.trim(),
      pickupLat: _pickupLat,
      pickupLng: _pickupLng,
      deliveryAddress: _deliveryAddressController.text.trim(),
      deliveryLat: _deliveryLat,
      deliveryLng: _deliveryLng,
      recipientName: _recipientNameController.text.trim(),
      recipientPhone: _recipientPhoneController.text.trim(),
      note: _noteController.text.trim(),
      itemName: _itemNameController.text.trim(),
      itemCategory: _itemCategory,
      itemDescription: _itemDescriptionController.text.trim(),
      cargoImage: _cargoImage,
      serviceType: _serviceType,
      paymentMethod: 'cash',
      deliveryFee: 30000.0,
    );

    context.push('/customer/create-order/confirm', extra: formData);
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
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 82,
      );

      if (image == null) return;

      if (!mounted) return;
      setState(() => _cargoImage = image);
    } on PlatformException catch (_) {
      if (!mounted) return;
      _showSnackBar(
        'Không thể mở thư viện ảnh. Vui lòng kiểm tra quyền truy cập ảnh.',
        isError: true,
      );
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Không thể chọn ảnh. Vui lòng thử lại.', isError: true);
    }
  }

  void _removeCargoImage() {
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
          'Đơn hàng mới',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.headingMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.bgCard,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      bottomNavigationBar: SubmitOrderButton(
        label: 'Tiếp tục',
        onPressed: _goToConfirmation,
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
                        onPickPickup: () => _openMapPicker('pickup'),
                        onPickDelivery: () => _openMapPicker('delivery'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      CreateOrderRecipientSection(
                        recipientNameController: _recipientNameController,
                        recipientPhoneController: _recipientPhoneController,
                        noteController: _noteController,
                        requiredText: _requiredText,
                        validatePhone: _validatePhone,
                      ),
                      const SizedBox(height: AppSpacing.md),
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
                      const SizedBox(height: AppSpacing.md),
                      CreateOrderServiceSection(
                        serviceType: _serviceType,
                        onChanged: (value) => setState(() {
                          _serviceType = value;
                        }),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const CreateOrderPaymentSection(),
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
