import 'package:delivery_app/core/models/recent_address_model.dart';
import 'package:delivery_app/core/models/saved_address_model.dart';
import 'package:delivery_app/core/services/address_cache_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('address cache separates saved and recent data by user', () async {
    final cache = AddressCacheService();
    final now = DateTime.utc(2026, 8, 3);
    final saved = SavedAddressModel(
      id: 'saved-1',
      userId: 'user-1',
      labelType: SavedAddressLabelType.home,
      formattedAddress: '12 Lê Lợi, Quận 1, Hồ Chí Minh',
      addressDetail: '',
      deliveryNote: 'Gọi trước khi đến',
      latitude: 10.77,
      longitude: 106.7,
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    );
    final recent = RecentAddressModel(
      id: 'recent-1',
      userId: 'user-1',
      addressType: RecentAddressType.delivery,
      formattedAddress: '25 Nguyễn Trãi, Quận 1, Hồ Chí Minh',
      addressDetail: 'Cổng B',
      deliveryNote: '',
      latitude: 10.78,
      longitude: 106.69,
      usageCount: 2,
      lastUsedAt: now,
    );

    await cache.writeSaved('user-1', [saved]);
    await cache.writeRecent('user-1', [recent]);

    expect((await cache.readSaved('user-1'))?.single.id, 'saved-1');
    expect((await cache.readRecent('user-1'))?.single.id, 'recent-1');
    expect(await cache.readSaved('user-2'), isNull);
  });

  test('cached empty list is different from a missing cache', () async {
    final cache = AddressCacheService();

    await cache.writeSaved('user-1', const []);

    expect(await cache.readSaved('user-1'), isEmpty);
    expect(await cache.readSaved('user-2'), isNull);
  });
}
