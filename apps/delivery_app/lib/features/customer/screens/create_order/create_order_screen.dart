import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../core/models/recent_address_model.dart';
import '../../../../core/providers/location_providers.dart';
import '../../../../core/utils/delivery_fee_calculator.dart';
import '../../../../core/utils/order_cargo_utils.dart';
import 'utils/vietnam_phone_input.dart';
import 'models/traffic_demo_scenario.dart';
import 'controllers/create_order_confirmation_controller.dart';
import 'controllers/order_finance_form_controller.dart';
import 'controllers/order_map_picker_controller.dart';
import 'controllers/order_quote_controller.dart';
import 'utils/create_order_feedback.dart';
import 'utils/order_cargo_picker.dart';
import 'utils/order_form_validators.dart';
import 'widgets/create_order_app_bar.dart';
import 'widgets/create_order_body.dart';
import 'widgets/fee_loading_dialog.dart';
import 'widgets/map_picker_sheet.dart';
import 'widgets/order_location_step.dart';
import 'widgets/order_quote_step.dart';
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
  final _financeController = OrderFinanceFormController();

  String _itemCategory = cargoCategories.first;
  XFile? _cargoImage;

  double _pickupLat = 0;
  double _pickupLng = 0;
  double _deliveryLat = 0;
  double _deliveryLng = 0;
  MapPickerResult? _pickupSelection;
  MapPickerResult? _deliverySelection;
  TrafficDemoScenario? _trafficDemoScenario;
  DeliveryFeeEstimate? _quote;
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
    _financeController.dispose();
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
    final isPickup = type == 'pickup';
    final outcome = await const OrderMapPickerController().pick(
      context: context,
      addressType: isPickup
          ? RecentAddressType.pickup
          : RecentAddressType.delivery,
      currentSelection: isPickup ? _pickupSelection : _deliverySelection,
      currentPosition: _currentPosition,
      locate: () => ref.read(locationServiceProvider).getCurrentPosition(),
    );
    if (!mounted) return;
    _currentPosition = outcome.currentPosition;
    if (outcome.usedFallback) {
      _showSnackBar(
        'Không thể định vị vị trí hiện tại. Vui lòng chọn vị trí trên bản đồ.',
        isError: true,
      );
    }
    final result = outcome.selection;
    if (!mounted || result == null) return;

    final address = result.address;
    final lat = result.position.latitude;
    final lng = result.position.longitude;

    setState(() {
      _trafficDemoScenario = null;
      _quote = null;
      if (isPickup) {
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
      _quote = null;
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
      'Đã điền tuyến AI mẫu. Nhấn “Xem giá giao hàng” để test ETA.',
    );
  }

  bool get _hasPickupPin => _pickupLat != 0 && _pickupLng != 0;
  bool get _hasDeliveryPin => _deliveryLat != 0 && _deliveryLng != 0;

  Future<void> _goToQuote() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FeeLoadingDialog(),
    );

    try {
      final quote = await OrderQuoteController().calculate(
        pickupLat: _pickupLat,
        pickupLng: _pickupLng,
        deliveryLat: _deliveryLat,
        deliveryLng: _deliveryLng,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() {
        _quote = quote;
        _step = 1;
      });
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showSnackBar('Không tính được phí giao hàng: $error', isError: true);
    }
  }

  void _goToInformation() => setState(() => _step = 2);

  Future<void> _goToConfirmation() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final quote = _quote;
    if (quote == null) {
      _showSnackBar('Vui lòng xem phí giao hàng trước.', isError: true);
      setState(() => _step = 0);
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FeeLoadingDialog(
        title: 'Đang chuẩn bị đơn',
        message: 'Đang kiểm tra thông tin trước khi xác nhận.',
        icon: Icons.fact_check_outlined,
      ),
    );

    try {
      final formData = await CreateOrderConfirmationController(ref).prepare(
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
        recipientName: _recipientNameController.text.trim(),
        recipientPhone: _recipientPhoneController.text.trim(),
        note: _noteController.text.trim(),
        itemName: _itemNameController.text.trim(),
        itemCategory: _itemCategory,
        itemDescription: _itemDescriptionController.text.trim(),
        cargoImage: _cargoImage,
        codCollectionAmount: _financeController.codCollectionAmount,
        quote: quote,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      context.push('/customer/create-order/confirm', extra: formData);
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _showSnackBar('Không thể chuẩn bị đơn hàng: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    showCreateOrderSnackBar(context, message, isError: isError);
  }

  Future<void> _pickCargoImage(ImageSource source) async {
    try {
      final image = await pickOrderCargoImage(source);
      if (!mounted || image == null) return;
      setState(() => _cargoImage = image);
    } on OrderCargoPickerException catch (error) {
      if (mounted) _showSnackBar(error.message, isError: true);
    }
  }

  void _autofillDemoData() {
    setState(() {
      _recipientNameController.text = 'Nguyễn Minh Anh';
      _recipientPhoneController.text = '0901234567';
      _noteController.text = 'Gọi trước khi giao hàng.';
      _itemNameController.text = 'Hộp bánh sinh nhật';
      _itemDescriptionController.text = 'Hàng dễ vỡ, vui lòng giữ thẳng.';
      _financeController.setCodCollectionAmount(50000);
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
    final quote = _quote;
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: isLocationStep
          ? null
          : CreateOrderAppBar(
              onBack: () => setState(() => _step -= 1),
              stepLabel: '${_step + 1} / 3',
              sectionLabel: switch (_step) {
                1 => 'Báo giá',
                _ => 'Thông tin',
              },
            ),
      bottomNavigationBar: isLocationStep
          ? null
          : SubmitOrderButton(
              label: switch (_step) {
                1 => 'Nhập thông tin đơn',
                _ => 'Kiểm tra đơn hàng',
              },
              subtitle: switch (_step) {
                1 => 'Thêm người nhận và kiện hàng',
                _ => 'Xem lại COD và tổng tiền',
              },
              onPressed: switch (_step) {
                1 => _goToInformation,
                _ => _goToConfirmation,
              },
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
              onContinue: _goToQuote,
              sampleRoutes: TrafficDemoRouteSelector(
                selectedId: _trafficDemoScenario?.id,
                onApply: _applyTrafficDemoScenario,
              ),
            )
          : SafeArea(
              child: switch (_step) {
                1 => OrderQuoteStep(
                  quote: quote!,
                  pickupAddress: _pickupAddressController.text,
                  deliveryAddress: _deliveryAddressController.text,
                ),
                _ => CreateOrderBody(
                  formKey: _formKey,
                  recipientNameController: _recipientNameController,
                  recipientPhoneController: _recipientPhoneController,
                  noteController: _noteController,
                  itemNameController: _itemNameController,
                  itemDescriptionController: _itemDescriptionController,
                  itemCategory: _itemCategory,
                  cargoImage: _cargoImage,
                  requiredText: requiredOrderText,
                  validatePhone: validateVietnamPhone,
                  onCategoryChanged: (value) =>
                      setState(() => _itemCategory = value),
                  onPickCamera: () => _pickCargoImage(ImageSource.camera),
                  onPickGallery: () => _pickCargoImage(ImageSource.gallery),
                  onRemoveImage: () => setState(() => _cargoImage = null),
                  onAutofillDemo: _autofillDemoData,
                  codCollectionController:
                      _financeController.codCollectionController,
                ),
              },
            ),
    );
  }
}
