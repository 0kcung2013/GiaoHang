import 'package:delivery_app/core/models/recent_address_model.dart';
import 'package:delivery_app/core/models/saved_address_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SavedAddressModel keeps location data without recipient fields', () {
    final address = SavedAddressModel.fromJson({
      'id': 'saved-1',
      'user_id': 'user-1',
      'label_type': 'other',
      'custom_label': 'Nhà ngoại',
      'formatted_address': 'Đường Nguyễn Trãi, Quận 1, Hồ Chí Minh',
      'address_detail': '25A, hẻm 12',
      'delivery_note': 'Nhà màu xanh',
      'latitude': 10.77,
      'longitude': 106.69,
      'is_default': true,
      'created_at': '2026-08-01T08:00:00Z',
      'updated_at': '2026-08-02T08:00:00Z',
      'contact_name': 'must not be read',
      'contact_phone': 'must not be read',
    });

    expect(address.labelType, SavedAddressLabelType.other);
    expect(address.customLabel, 'Nhà ngoại');
    expect(
      address.fullAddress,
      '25A, hẻm 12, Đường Nguyễn Trãi, Quận 1, Hồ Chí Minh',
    );
    expect(address.toMutationJson(), isNot(contains('contact_name')));
    expect(address.toMutationJson(), isNot(contains('contact_phone')));
  });

  test('RecentAddressModel preserves address type and usage metadata', () {
    final address = RecentAddressModel.fromJson({
      'id': 'recent-1',
      'user_id': 'user-1',
      'address_type': 'pickup',
      'formatted_address': '12 Lê Lợi, Quận 1, Hồ Chí Minh',
      'address_detail': 'Tầng 2',
      'delivery_note': '',
      'latitude': 10.775,
      'longitude': 106.7,
      'usage_count': 4,
      'last_used_at': '2026-08-02T08:00:00Z',
    });

    expect(address.addressType, RecentAddressType.pickup);
    expect(address.usageCount, 4);
    expect(address.toRecordJson(), isNot(contains('usage_count')));
    expect(address.toRecordJson(), isNot(contains('user_id')));
  });
}
