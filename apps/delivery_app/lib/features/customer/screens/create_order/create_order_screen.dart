import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../core/models/recent_address_model.dart';
import '../../../../core/providers/location_providers.dart';
import '../../../../core/utils/delivery_fee_calculator.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../../../core/utils/order_cargo_utils.dart';
import 'utils/order_form_data.dart';
import 'utils/sender_contact_loader.dart';
import 'utils/vietnam_phone_input.dart';
import 'models/traffic_demo_scenario.dart';
import 'widgets/create_order_app_bar.dart';
import 'widgets/create_order_body.dart';
import 'widgets/fee_loading_dialog.dart';
import 'widgets/map_picker_sheet.dart';
import 'widgets/order_location_step.dart';
import 'widgets/submit_order_button.dart';
import 'widgets/traffic_demo_route_selector.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
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

  static const _serviceType = 'standard';
  String _itemCategory = cargoCategories.first;
  XFile? _cargoImage;

  double _pickupLat = 0;
  double _pickupLng = 0;
  double _deliveryLat = 0;
  double _deliveryLng = 0;
  MapPickerResult? _pickupSelection;
  MapPickerResult? _deliverySelection;
  TrafficDemoScenario? _trafficDemoScenario;
  var _step = 0;

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
      _currentPosition ??= await ref
          .read(locationServiceProvider)
          .getCurrentPosition();
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

    if (!mounted) return;
    final result = await showModalBottomSheet<MapPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MapPickerSheet(
        initialPosition: initialPos,
        addressType: type == 'pickup'
            ? RecentAddressType.pickup
            : RecentAddressType.delivery,
        initialSelection: type == 'pickup'
            ? _pickupSelection
            : _deliverySelection,
      ),
    );

    if (!mounted || result == null) return;

    final address = result.address;
    final lat = result.position.latitude;
    final lng = result.position.longitude;

    setState(() {
      _trafficDemoScenario = null;
      if (type == 'pickup') {
        _pickupSelection = result;
        _pickupLat = lat;
        _pickupLng = lng;
        _pickupAddressController.text = address;
      } else {
        _deliverySelection = result;
        _deliveryLat = lat;
        _deliveryLng = lng;
        _deliveryAddressController.text = address;
      }
    });
  }

  void _applyTrafficDemoScenario(TrafficDemoScenario scenario) {
    setState(() {
      _trafficDemoScenario = scenario;
      _pickupLat = scenario.pickup.latitude;
      _pickupLng = scenario.pickup.longitude;
      _deliveryLat = scenario.delivery.latitude;
      _deliveryLng = scenario.delivery.longitude;
      _pickupSelection = MapPickerResult(
        position: scenario.pickup,
        formattedAddress: scenario.pickupAddress,
        addressDetail: '',
        deliveryNote: 'Tuyến AI mẫu dùng để kiểm thử ETA',
      );
      _deliverySelection = MapPickerResult(
        position: scenario.delivery,
        formattedAddress: scenario.deliveryAddress,
        addressDetail: '',
        deliveryNote: 'Tuyến AI mẫu dùng để kiểm thử ETA',
      );
      _pickupAddressController.text = scenario.pickupAddress;
      _deliveryAddressController.text = scenario.deliveryAddress;
    });
    _showSnackBar(
      'Đã điền tuyến AI mẫu. Nhấn “Xem giá và tiếp tục” để test ETA.',
    );
  }

  bool get _hasPickupPin => _pickupLat != 0 && _pickupLng != 0;
  bool get _hasDeliveryPin => _deliveryLat != 0 && _deliveryLng != 0;

  void _goToInformation() {
    if (!_hasPickupPin || !_hasDeliveryPin) return;
    setState(() => _step = 1);
  }

  Future<void> _goToConfirmation() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasPickupPin) {
      _showSnackBar(
        'Vui lòng chọn điểm lấy hàng trên bản đồ (nút map).',
        isError: true,
      );
      return;
    }
    if (!_hasDeliveryPin) {
      _showSnackBar(
        'Vui lòng chọn điểm giao hàng trên bản đồ (nút map).',
        isError: true,
      );
      return;
    }

    final distM = GeoUtils.distanceMeters(
      fromLat: _pickupLat,
      fromLng: _pickupLng,
      toLat: _deliveryLat,
      toLng: _deliveryLng,
    );
    if (distM < 50) {
      _showSnackBar(
        'Điểm lấy và điểm giao quá gần nhau. Vui lòng kiểm tra lại.',
        isError: true,
      );
      return;
    }

    late final SenderContactData sender;
    try {
      sender = await loadSenderContact(ref);
    } on SenderContactException catch (error) {
      if (mounted) _showSnackBar(error.message, isError: true);
      return;
    }
    if (!mounted) return;

    // Loading nhẹ khi tính phí / OSRM
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FeeLoadingDialog(),
    );

    try {
      final estimate = await DeliveryFeeCalculator.estimate(
        pickupLat: _pickupLat,
        pickupLng: _pickupLng,
        deliveryLat: _deliveryLat,
        deliveryLng: _deliveryLng,
        serviceType: _serviceType,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // đóng loading

      final formData = OrderFormData(
        pickupAddress: _pickupAddressController.text.trim(),
        pickupFormattedAddress:
            _pickupSelection?.formattedAddress ??
            _pickupAddressController.text.trim(),
        pickupAddressDetail: _pickupSelection?.addressDetail ?? '',
        pickupDeliveryNote: _pickupSelection?.deliveryNote ?? '',
        pickupLat: _pickupLat,
        pickupLng: _pickupLng,
        deliveryAddress: _deliveryAddressController.text.trim(),
        deliveryFormattedAddress:
            _deliverySelection?.formattedAddress ??
            _deliveryAddressController.text.trim(),
        deliveryAddressDetail: _deliverySelection?.addressDetail ?? '',
        deliveryDeliveryNote: _deliverySelection?.deliveryNote ?? '',
        deliveryLat: _deliveryLat,
        deliveryLng: _deliveryLng,
        senderName: sender.name,
        senderPhone: sender.phone,
        recipientName: _recipientNameController.text.trim(),
        recipientPhone: _recipientPhoneController.text.trim(),
        note: _noteController.text.trim(),
        itemName: _itemNameController.text.trim(),
        itemCategory: _itemCategory,
        itemDescription: _itemDescriptionController.text.trim(),
        cargoImage: _cargoImage,
        paymentMethod: 'cash',
        deliveryFee: estimate.deliveryFee,
        totalPrice: estimate.totalPrice,
        distanceMeters: estimate.distanceMeters,
        durationSeconds: estimate.durationSeconds,
        distanceSource: estimate.source,
        feeBreakdown: estimate.feeBreakdown,
        deliveryEta: estimate.eta,
      );

      if (!mounted) return;
      context.push('/customer/create-order/confirm', extra: formData);
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _showSnackBar('Không tính được phí giao hàng: $e', isError: true);
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

  Future<void> _pickCargoImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: kIsWeb ? ImageSource.gallery : source,
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

  void _autofillDemoData() {
    setState(() {
      _recipientNameController.text = 'Nguyễn Minh Anh';
      _recipientPhoneController.text = '0901234567';
      _noteController.text = 'Gọi trước khi giao hàng.';
      _itemNameController.text = 'Hộp bánh sinh nhật';
      _itemDescriptionController.text = 'Hàng dễ vỡ, vui lòng giữ thẳng.';
      _itemCategory = cargoCategories.first;
    });
    _showSnackBar('Đã điền dữ liệu demo.');
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = LatLng(
      _currentPosition?.latitude ?? 10.762622,
      _currentPosition?.longitude ?? 106.660172,
    );
    final isLocationStep = _step == 0;
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: isLocationStep
          ? null
          : CreateOrderAppBar(onBack: () => setState(() => _step = 0)),
      bottomNavigationBar: isLocationStep
          ? null
          : SubmitOrderButton(
              label: 'Xem giá và tiếp tục',
              onPressed: _goToConfirmation,
            ),
      body: isLocationStep
          ? OrderLocationStep(
              initialCenter: initialCenter,
              pickup: _hasPickupPin ? LatLng(_pickupLat, _pickupLng) : null,
              delivery: _hasDeliveryPin
                  ? LatLng(_deliveryLat, _deliveryLng)
                  : null,
              pickupAddress: _pickupAddressController.text,
              deliveryAddress: _deliveryAddressController.text,
              onPickPickup: () => _openMapPicker('pickup'),
              onPickDelivery: () => _openMapPicker('delivery'),
              onContinue: _goToInformation,
              sampleRoutes: TrafficDemoRouteSelector(
                selectedId: _trafficDemoScenario?.id,
                onApply: _applyTrafficDemoScenario,
              ),
            )
          : SafeArea(
              child: CreateOrderBody(
                formKey: _formKey,
                recipientNameController: _recipientNameController,
                recipientPhoneController: _recipientPhoneController,
                noteController: _noteController,
                itemNameController: _itemNameController,
                itemDescriptionController: _itemDescriptionController,
                itemCategory: _itemCategory,
                cargoImage: _cargoImage,
                requiredText: _requiredText,
                validatePhone: _validatePhone,
                onCategoryChanged: (value) =>
                    setState(() => _itemCategory = value),
                onPickCamera: () => _pickCargoImage(ImageSource.camera),
                onPickGallery: () => _pickCargoImage(ImageSource.gallery),
                onRemoveImage: _removeCargoImage,
                onAutofillDemo: _autofillDemoData,
              ),
            ),
    );
  }

  // Retained for validation compatibility with saved address entry points.
  // ignore: unused_element
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
    return validateVietnamPhone(value);
  }
}
