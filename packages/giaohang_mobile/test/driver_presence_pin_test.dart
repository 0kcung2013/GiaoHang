import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:giaohang_mobile/core/location/driver_presence_strings.dart';
import 'package:giaohang_mobile/core/providers/customer_providers.dart';
import 'package:giaohang_mobile/core/providers/location_providers.dart';
import 'package:giaohang_mobile/core/services/driver_service.dart';
import 'package:giaohang_mobile/features/driver/screens/home/widgets/availability_toggle_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'driver_presence_session_test.dart' show Gps;
import 'helpers/utraffic_capture_fonts.dart';

void main() {
  late SupabaseClient client;
  setUpAll(() {
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  });
  tearDownAll(() => client.dispose());
  setUpAll(prepareUtrafficCaptureFonts);
  for (final scenario in [
    (accurate: true, cancel: false),
    (accurate: false, cancel: false),
    (accurate: true, cancel: true),
  ]) {
    final accurate = scenario.accurate;
    testWidgets(
      'PIN submission validates GPS: $accurate, cancelled: ${scenario.cancel}',
      (tester) async {
        var acquisitions = 0;
        final pending = Completer<Position?>();
        Position position() => Position(
          latitude: 10.889,
          longitude: 106.701,
          timestamp: DateTime.now(),
          accuracy: accurate ? 126 : 201,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
        final gps = Gps(() async {
          acquisitions++;
          if (scenario.cancel) return pending.future;
          return position();
        });
        var commands = 0;
        double? sentLatitude;
        final service = DriverService(
          client: client,
          locationPublisher:
              ({
                required driverProfileId,
                required lat,
                required lng,
                heading,
                speed,
              }) async {
                sentLatitude = lat;
              },
          presenceInvoker: (_) async {},
          rpcInvoker: (name, _) async {
            if (name == 'get_driver_online_pin_status') {
              return {'is_configured': true};
            }
            commands++;
            return {'status': 'online', 'offered_order_id': 'order'};
          },
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              driverServiceProvider.overrideWithValue(service),
              locationServiceProvider.overrideWithValue(gps),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: AvailabilityToggleCard(
                  driver: DriverModel(
                    id: 'profile',
                    userId: 'driver',
                    isAvailable: false,
                    updatedAt: DateTime.now(),
                    totalDeliveries: 0,
                  ),
                  hasActiveOrder: false,
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(
          acquisitions,
          0,
          reason: 'Do not freeze GPS while the user enters PIN',
        );
        await tester.enterText(
          find.byKey(const ValueKey('driver-online-pin')),
          '123456',
        );
        if (scenario.cancel) {
          await tester.pump();
          Navigator.of(
            tester.element(find.byKey(const ValueKey('driver-online-pin'))),
          ).pop();
          await tester.pumpAndSettle();
          pending.complete(position());
        }
        await tester.pumpAndSettle();
        expect(acquisitions, 1);
        expect(commands, accurate && !scenario.cancel ? 1 : 0);
        expect(sentLatitude, accurate && !scenario.cancel ? 10.889 : isNull);
        if (!accurate) {
          expect(
            find.textContaining(DriverPresenceStrings.inaccurate),
            findsOneWidget,
          );
        }
      },
    );
  }
}
