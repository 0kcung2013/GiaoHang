import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:geolocator/geolocator.dart';
import 'package:giaohang_mobile/core/services/location_service.dart';
import 'package:giaohang_mobile/features/driver/screens/home/widgets/driver_online_pin_input.dart';
import 'package:giaohang_mobile/features/driver/screens/home/widgets/driver_online_pin_verification_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'driver_presence_session_test.dart' show fix;
import 'location_acquisition_timeout_test.dart' show WebGpsPlatform;
import 'helpers/utraffic_capture_fonts.dart';

void main() {
  setUpAll(prepareUtrafficCaptureFonts);

  for (final size in [
    const Size(320, 568),
    const Size(360, 800),
    const Size(1024, 768),
  ]) {
    testWidgets(
      'GPS failure retains the PIN and retries position without retyping at $size',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final boundary = GlobalKey();
        final previous = GeolocatorPlatform.instance;
        final platform = WebGpsPlatform();
        GeolocatorPlatform.instance = platform;
        final service = LocationService(isWeb: true);
        addTearDown(() {
          service.dispose();
          GeolocatorPlatform.instance = previous;
        });
        String? result;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.6)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: FilledButton(
                    onPressed: () async {
                      result = await showDriverOnlinePinVerificationSheet(
                        context,
                        isSetup: false,
                        onVerify: (_) async {
                          await service.getOnlinePosition();
                        },
                      );
                    },
                    child: const Text('Mở'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Mở'));
        await tester.pumpAndSettle();
        final input = find.byKey(const ValueKey('driver-online-pin'));
        await tester.enterText(input, '123456');
        await tester.pump();
        await tester.pump(const Duration(seconds: 30));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<EditableText>(
                find.descendant(of: input, matching: find.byType(EditableText)),
              )
              .controller
              .text,
          '123456',
        );
        expect(
          tester
              .widget<DriverOnlinePinField>(find.byType(DriverOnlinePinField))
              .hasError,
          isFalse,
        );
        expect(result, isNull);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Thử lại vị trí'));
        await tester.pumpAndSettle();
        if (size.width == 360) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              '../../artifacts/driver_online_pin_location_retry.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.text('Thử lại vị trí'));
        await tester.pump();
        platform.controllers.last.add(fix(DateTime.now()));
        await tester.pumpAndSettle();
        expect(result, '123456');
      },
    );
  }
  testWidgets('setup verifies automatically after six matching digits', (
    tester,
  ) async {
    String? result;
    final verifiedPins = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showDriverOnlinePinVerificationSheet(
                  context,
                  isSetup: true,
                  onVerify: (pin) async => verifiedPins.add(pin),
                );
              },
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('driver-online-pin')),
      '123456',
    );
    await tester.enterText(
      find.byKey(const ValueKey('driver-online-pin-confirmation')),
      '654321',
    );
    await tester.pump();

    expect(find.text('Hai mã PIN chưa khớp. Hãy nhập lại.'), findsOneWidget);
    expect(verifiedPins, isEmpty);
    expect(result, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('driver-online-pin-confirmation')),
      '123456',
    );
    await tester.pumpAndSettle();

    expect(verifiedPins, ['123456']);
    expect(result, '123456');
  });

  testWidgets('existing PIN shows an immediate error and allows retry', (
    tester,
  ) async {
    String? result;
    final verifiedPins = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showDriverOnlinePinVerificationSheet(
                  context,
                  isSetup: false,
                  onVerify: (pin) async {
                    verifiedPins.add(pin);
                    if (pin == '123456') {
                      throw Exception('Mã PIN không đúng. Bạn còn 4 lần thử.');
                    }
                  },
                );
              },
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('driver-online-pin-digit')),
      findsNWidgets(6),
    );

    await tester.enterText(
      find.byKey(const ValueKey('driver-online-pin')),
      '123456',
    );
    await tester.pumpAndSettle();

    expect(find.text('Mã PIN không đúng. Bạn còn 4 lần thử.'), findsOneWidget);
    expect(result, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('driver-online-pin')),
      '654321',
    );
    await tester.pumpAndSettle();

    expect(verifiedPins, ['123456', '654321']);
    expect(result, '654321');
  });
}
