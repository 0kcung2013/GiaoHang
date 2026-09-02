import 'package:delivery_app/core/models/saved_address_model.dart';
import 'package:delivery_app/features/customer/screens/create_order/controllers/address_picker_controller.dart';
import 'package:delivery_app/features/customer/screens/create_order/models/address_picker_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('requires address detail when map result has no house number', () {
    final controller = AddressPickerController(
      initialPosition: const LatLng(10.7626, 106.6602),
      initialSelection: const MapPickerResult(
        position: LatLng(10.7626, 106.6602),
        formattedAddress: 'Đường Nguyễn Trãi, Quận 5, TP. Hồ Chí Minh',
        addressDetail: '',
        deliveryNote: '',
      ),
    );
    addTearDown(controller.dispose);

    expect(controller.validate(), isFalse);
    expect(controller.detailError, isNotNull);

    controller.detailController.text = 'Số 123, hẻm bên cạnh nhà thuốc';
    expect(controller.validate(), isTrue);
    expect(controller.buildResult().addressDetail, startsWith('Số 123'));
  });

  test('accepts a one-digit house number as address detail', () {
    final controller = AddressPickerController(
      initialPosition: const LatLng(10.7626, 106.6602),
      initialSelection: const MapPickerResult(
        position: LatLng(10.7626, 106.6602),
        formattedAddress: 'Đường Nguyễn Trãi, Quận 5, TP. Hồ Chí Minh',
        addressDetail: '',
        deliveryNote: '',
      ),
    );
    addTearDown(controller.dispose);

    controller.detailController.text = '1';

    expect(controller.validate(), isTrue);
    expect(controller.detailError, isNull);
    expect(controller.buildResult().addressDetail, '1');
  });

  test('requires a custom label when saving an address as other', () {
    final controller = AddressPickerController(
      initialPosition: const LatLng(10.7626, 106.6602),
      initialSelection: const MapPickerResult(
        position: LatLng(10.7626, 106.6602),
        formattedAddress: '123 Nguyễn Trãi, Quận 5, TP. Hồ Chí Minh',
        addressDetail: 'Tòa nhà A',
        deliveryNote: 'Gọi trước khi đến',
      ),
    );
    addTearDown(controller.dispose);

    controller.setSaveAddress(true);
    controller.setLabelType(SavedAddressLabelType.other);
    expect(controller.validate(), isFalse);
    expect(controller.customLabelError, isNotNull);

    controller.customLabelController.text = 'Kho phụ';
    expect(controller.validate(), isTrue);

    final saved = controller.buildSavedAddress('user-1');
    expect(saved.customLabel, 'Kho phụ');
    expect(saved.deliveryNote, 'Gọi trước khi đến');
  });
}
