import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:giaohang_mobile/core/location/location_failure.dart';
import 'package:giaohang_mobile/core/location/driver_presence_strings.dart';
import 'package:giaohang_mobile/core/providers/location_providers.dart';
import 'package:giaohang_mobile/features/driver/screens/widgets/driver_gps_debug_dialog.dart';
import 'package:giaohang_mobile/features/driver/screens/widgets/driver_gps_debug_providers.dart';
import 'package:giaohang_mobile/features/driver/screens/widgets/driver_gps_debug_strings.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'driver_presence_session_test.dart' show Gps;
import 'helpers/utraffic_capture_fonts.dart';

final _user = User(
  id: 'driver',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-11-03T00:00:00Z',
  email: 'driver@example.com',
);

void main() {
  setUpAll(prepareUtrafficCaptureFonts);
  testWidgets(
    'slow server does not postpone requesting GPS or hide the actual GPS error',
    (tester) async {
      final profile = Completer<DriverModel?>();
      var gpsCalls = 0;
      final gps = Gps(() async {
        gpsCalls++;
        return null;
      })..lastFailure = LocationFailure.unavailable;
      final scope = ProviderContainer(
        overrides: [
          driverGpsDebugUserProvider.overrideWithValue(() => _user),
          driverGpsDebugProfileProvider.overrideWithValue(
            (_) => profile.future,
          ),
          locationServiceProvider.overrideWithValue(gps),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: const MaterialApp(home: Scaffold(body: DriverGpsDebugSheet())),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(gpsCalls, 1);
      expect(profile.isCompleted, isFalse);
      expect(
        find.text(DriverPresenceStrings.positionUnavailable),
        findsOneWidget,
      );
      expect(find.text(_user.email!), findsOneWidget);
      expect(find.text(DriverGpsDebugStrings.loading), findsNothing);
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpWidget(const SizedBox.shrink());
      scope.dispose();
      profile.complete(null);
    },
  );

  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets(
      'hung device and profile stop showing skeleton after 8 seconds at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final profile = Completer<DriverModel?>();
        final gps = Gps(() => Completer<Position?>().future);
        final scope = ProviderContainer(
          overrides: [
            driverGpsDebugUserProvider.overrideWithValue(() => _user),
            driverGpsDebugProfileProvider.overrideWithValue(
              (_) => profile.future,
            ),
            locationServiceProvider.overrideWithValue(gps),
          ],
        );
        final boundary = GlobalKey();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: scope,
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(1.6),
                ),
                child: RepaintBoundary(
                  key: boundary,
                  child: const Scaffold(body: DriverGpsDebugSheet()),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text(DriverGpsDebugStrings.loading), findsOneWidget);
        await tester.pump(const Duration(seconds: 8));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text(DriverGpsDebugStrings.loading), findsNothing);
        expect(find.text(DriverPresenceStrings.gpsTimedOut), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (size.width == 390) {
          await tester.runAsync(() async {
            final capture =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await capture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              '../../artifacts/driver_gps_timeout_diagnostic.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            capture.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
        scope.dispose();
        profile.complete(null);
      },
    );
  }
}
