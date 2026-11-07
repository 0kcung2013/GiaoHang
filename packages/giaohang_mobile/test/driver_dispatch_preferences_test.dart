import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_mobile/core/providers/customer_providers.dart';
import 'package:giaohang_mobile/features/driver/dispatch_preferences/dispatch_preferences.dart';
import 'package:giaohang_mobile/features/driver/dispatch_preferences/dispatch_preferences_providers.dart';
import 'package:giaohang_mobile/features/driver/dispatch_preferences/dispatch_preferences_screen.dart';
import 'package:giaohang_mobile/features/driver/dispatch_preferences/dispatch_preferences_strings.dart';
import 'package:giaohang_mobile/features/driver/screens/widgets/driver_drawer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/utraffic_capture_fonts.dart';

const areas = [
  OperatingArea(
    id: '718',
    provinceCode: '74',
    provinceName: 'Tỉnh Bình Dương',
    name: 'Thành phố Thủ Dầu Một',
  ),
  OperatingArea(
    id: '725',
    provinceCode: '74',
    provinceName: 'Tỉnh Bình Dương',
    name: 'Thành phố Thuận An',
  ),
  OperatingArea(
    id: '760',
    provinceCode: '79',
    provinceName: 'Thành phố Hồ Chí Minh',
    name: 'Quận 1',
  ),
];

class FakePreferencesRepository extends DispatchPreferencesRepository {
  FakePreferencesRepository()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  DispatchPreferences? saved;
  bool failPending = false;
  @override
  Future<void> save(DispatchPreferences preferences) async {
    if (failPending) {
      throw const PostgrestException(message: 'DISPATCH_OFFER_PENDING');
    }
    saved = preferences;
  }
}

void main() {
  setUpAll(prepareUtrafficCaptureFonts);
  test(
    'existing driver defaults to nearby; preferences retain server destination expiry',
    () {
      expect(DispatchPreferences.fromJson({}).mode, DispatchMode.nearby);
      final json = {
        'dispatch_mode': 'destination',
        'operating_area_id': null,
        'destination_lat': 11.1,
        'destination_lng': 106.7,
        'destination_label': 'Nhà',
        'destination_expires_at': '2026-11-05T12:00:00.000Z',
        'nearby_delivery_limit_m': null,
      };
      expect(DispatchPreferences.fromJson(json).toJson(), json);
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(1024, 768),
  ]) {
    testWidgets('area selection and save are usable at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final repository = FakePreferencesRepository();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dispatchPreferencesRepositoryProvider.overrideWithValue(repository),
            operatingAreasProvider.overrideWith((ref) async => areas),
            driverByUserIdProvider('driver').overrideWith((ref) async => null),
          ],
          child: RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent),
                textTheme: TextTheme(bodyMedium: AppTextStyles.bodyMedium),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(size.width == 390 ? 1 : 1.6),
                ),
                child: child!,
              ),
              home: const DispatchPreferencesScreen(
                userId: 'driver',
                initial: DispatchPreferences(
                  mode: DispatchMode.area,
                  areaId: '718',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Thành phố Thủ Dầu Một'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Thành phố Thủ Dầu Một'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Thành phố Thủ Dầu Một'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thành phố Thuận An').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text(DispatchPreferencesStrings.save));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = File(
          '../../artifacts/driver_dispatch_area_${size.width.toInt()}.png',
        );
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.tap(find.text(DispatchPreferencesStrings.save));
      await tester.pumpAndSettle();
      expect(repository.saved?.mode, DispatchMode.area);
      expect(repository.saved?.areaId, '725');
    });
  }

  testWidgets(
    'nearby saves the selected delivery range and keeps the save action visible',
    (tester) async {
      final repository = FakePreferencesRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dispatchPreferencesRepositoryProvider.overrideWithValue(repository),
            driverByUserIdProvider('driver').overrideWith((ref) async => null),
          ],
          child: const MaterialApp(
            home: DispatchPreferencesScreen(
              userId: 'driver',
              initial: DispatchPreferences(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(DispatchPreferencesStrings.underFive));
      await tester.pumpAndSettle();
      await tester.tap(find.text(DispatchPreferencesStrings.save));
      await tester.pumpAndSettle();
      expect(repository.saved?.nearbyDeliveryLimitMeters, 5000);
      expect(repository.saved?.mode, DispatchMode.nearby);
    },
  );

  testWidgets(
    'area search accepts unaccented Vietnamese and a cancelled choice preserves the selection',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            operatingAreasProvider.overrideWith((ref) async => areas),
            driverByUserIdProvider('driver').overrideWith((ref) async => null),
          ],
          child: const MaterialApp(
            home: DispatchPreferencesScreen(
              userId: 'driver',
              initial: DispatchPreferences(
                mode: DispatchMode.area,
                areaId: '718',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thành phố Thủ Dầu Một'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'thuan an');
      await tester.pumpAndSettle();
      expect(find.text('Thành phố Thuận An'), findsOneWidget);
      await tester.tap(find.byTooltip(DispatchPreferencesStrings.close));
      await tester.pumpAndSettle();
      expect(find.text('Thành phố Thủ Dầu Một'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dispatch menu is first and opens its own tab', (tester) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(),
          drawer: DriverDrawer(
            currentIndex: 0,
            onNavigate: (index) => selected = index,
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text(DispatchPreferencesStrings.title)).dy,
      lessThan(tester.getTopLeft(find.text('Tổng quan')).dy),
    );
    await tester.tap(find.text(DispatchPreferencesStrings.title));
    await tester.pumpAndSettle();
    expect(selected, 5);
  });
  testWidgets(
    'changing province clears area and disables save until selection',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            operatingAreasProvider.overrideWith((ref) async => areas),
            driverByUserIdProvider('driver').overrideWith((ref) async => null),
          ],
          child: const MaterialApp(
            home: DispatchPreferencesScreen(
              userId: 'driver',
              initial: DispatchPreferences(
                mode: DispatchMode.area,
                areaId: '718',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tỉnh Bình Dương'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thành phố Hồ Chí Minh').last);
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, DispatchPreferencesStrings.save),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Thành phố Thủ Dầu Một'), findsNothing);
    },
  );

  testWidgets(
    'pending offer reports the server error and preserves chosen mode',
    (tester) async {
      final repository = FakePreferencesRepository()..failPending = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dispatchPreferencesRepositoryProvider.overrideWithValue(repository),
            driverByUserIdProvider('driver').overrideWith((ref) async => null),
          ],
          child: const MaterialApp(
            home: DispatchPreferencesScreen(
              userId: 'driver',
              initial: DispatchPreferences(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(DispatchPreferencesStrings.save));
      await tester.pumpAndSettle();
      expect(
        find.text(DispatchPreferencesStrings.pendingOffer),
        findsOneWidget,
      );
      expect(repository.saved, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
