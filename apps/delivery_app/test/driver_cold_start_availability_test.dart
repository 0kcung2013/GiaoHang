import 'package:delivery_app/core/providers/customer_providers.dart';
import 'package:delivery_app/core/services/driver_service.dart';
import 'package:delivery_app/features/driver/providers/driver_cold_start_availability.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('reload preserves the online state stored on the server', () async {
    final service = _MemoryDriverService(isAvailable: true);
    final container = ProviderContainer(
      overrides: [driverServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    await container.read(
      driverColdStartAvailabilityProvider('driver-user-1').future,
    );

    expect(service.isAvailable, isTrue);
    expect(service.availabilityWrites, isZero);
  });
}

class _MemoryDriverService extends DriverService {
  _MemoryDriverService({required this.isAvailable})
    : super(
        client: SupabaseClient('https://example.supabase.co', 'test-anon-key'),
        locationPublisher:
            ({
              required driverProfileId,
              required lat,
              required lng,
              heading,
              speed,
            }) async {},
      );

  bool isAvailable;
  int availabilityWrites = 0;

  @override
  Future<void> updateAvailability(bool value) async {
    availabilityWrites += 1;
    isAvailable = value;
  }

  @override
  Future<DriverModel?> getDriverByUserId(String userId) async {
    return DriverModel(
      id: 'driver-profile-1',
      userId: userId,
      isAvailable: isAvailable,
      updatedAt: DateTime(2026, 8, 25),
      totalDeliveries: 0,
    );
  }
}
