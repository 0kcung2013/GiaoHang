import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/providers/customer_providers.dart';
import 'package:delivery_app/core/services/driver_service.dart';
import 'package:delivery_app/features/driver/cancellation/driver_cancellation_providers.dart';
import 'package:delivery_app/features/driver/cancellation/driver_cancellation_strings.dart';
import 'package:delivery_app/features/driver/cancellation/models/driver_acceptance_state.dart';
import 'package:delivery_app/features/driver/screens/home/driver_home_strings.dart';
import 'package:delivery_app/features/driver/screens/home/widgets/driver_offline_confirmation_sheet.dart';
import 'package:delivery_app/features/driver/screens/widgets/driver_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  final now = DateTime.utc(2026, 9, 27, 10);
  final order = OrderModel(
    id: 'order-1',
    customerId: 'customer-1',
    driverId: 'driver-1',
    status: 'assigned',
    pickupAddress: 'Điểm lấy',
    pickupLat: 10.8,
    pickupLng: 106.7,
    deliveryAddress: 'Điểm giao',
    deliveryLat: 10.81,
    deliveryLng: 106.71,
    createdAt: now,
    trackingCode: 'GH-001',
    deliveryFee: 20000,
    updatedAt: now,
    serviceType: 'standard',
    paymentMethod: 'cash',
  );

  Future<void> openMenu(
    WidgetTester tester,
    _MemoryDriverService service, {
    bool active = false,
    bool locked = false,
    bool stateError = false,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(375, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scaffoldKey = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          driverServiceProvider.overrideWithValue(service),
          driverByUserIdProvider.overrideWith(
            (ref, id) => service.getDriverByUserId(id),
          ),
          driverOrdersProvider.overrideWith(
            (ref, id) => Stream.value(active ? [order] : []),
          ),
          availableOrdersProvider.overrideWith((ref, id) => Stream.value([])),
          driverAcceptanceStateProvider.overrideWith(
            (ref, id) => stateError
                ? Stream.error(Exception('offline'))
                : Stream.value(
                    DriverAcceptanceState(
                      serverNow: now,
                      lockedUntil: locked
                          ? now.add(const Duration(minutes: 30))
                          : null,
                    ),
                  ),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            key: scaffoldKey,
            drawer: DriverDrawer(
              userId: 'driver-1',
              currentIndex: 0,
              onNavigate: (_) {},
            ),
            body: const Text('Trang chính'),
          ),
        ),
      ),
    );
    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();
  }

  testWidgets('menu asks before disabling; keeping online writes nothing', (
    tester,
  ) async {
    final service = _MemoryDriverService();
    await openMenu(tester, service);
    expect(find.text(DriverHomeStrings.activityLabel), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.byType(DriverOfflineConfirmationSheet), findsOneWidget);
    expect(service.writes, 0);
    expect(service.online, isTrue);
    await tester.tap(find.text(DriverHomeStrings.offlineKeepAction));
    await tester.pumpAndSettle();
    expect(service.writes, 0);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('confirmed disable writes once and updates menu status', (
    tester,
  ) async {
    final service = _MemoryDriverService();
    await openMenu(tester, service);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(service.writes, 0);
    await tester.tap(find.text(DriverHomeStrings.offlineConfirmAction));
    await tester.pumpAndSettle();
    expect(service.writes, 1);
    expect(service.online, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.text(DriverHomeStrings.activityOffline), findsOneWidget);
  });

  testWidgets('dismissing confirmation leaves receiving orders on', (
    tester,
  ) async {
    final service = _MemoryDriverService();
    await openMenu(tester, service);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    final sheetContext = tester.element(
      find.byType(DriverOfflineConfirmationSheet),
    );
    Navigator.of(sheetContext).pop();
    await tester.pumpAndSettle();
    expect(service.writes, 0);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('failed disable keeps the current status and reports the error', (
    tester,
  ) async {
    final service = _MemoryDriverService()..fail = true;
    await openMenu(tester, service);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text(DriverHomeStrings.offlineConfirmAction));
    await tester.pumpAndSettle();
    expect(service.writes, 1);
    expect(service.online, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.text('Chưa tắt được app'), findsOneWidget);
  });

  testWidgets('active delivery allows confirmed stopping of new orders', (
    tester,
  ) async {
    final service = _MemoryDriverService();
    await openMenu(tester, service, active: true);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
    expect(find.text('Trạng thái hoạt động'), findsOneWidget);
    expect(find.text(DriverHomeStrings.activityOnline), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(service.writes, 0);
    expect(
      find.text(DriverHomeStrings.offlineActiveOrderConfirmMessage),
      findsOneWidget,
    );
    await tester.tap(find.text(DriverHomeStrings.offlineConfirmAction));
    await tester.pumpAndSettle();
    expect(service.writes, 1);
    expect(service.online, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
    expect(find.text(DriverHomeStrings.activityOffline), findsOneWidget);
  });

  testWidgets('cancellation lock prevents resuming new orders', (tester) async {
    final service = _MemoryDriverService()..online = false;
    await openMenu(tester, service, locked: true);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(find.text(DriverCancellationStrings.lockTitle), findsOneWidget);
    expect(service.writes, 0);
  });

  testWidgets('cancellation lock still allows stopping new orders', (
    tester,
  ) async {
    final service = _MemoryDriverService();
    await openMenu(tester, service, locked: true);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text(DriverHomeStrings.offlineConfirmAction));
    await tester.pumpAndSettle();
    expect(service.writes, 1);
    expect(service.online, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
  });

  testWidgets('unavailable lock state prevents toggling and exposes retry', (
    tester,
  ) async {
    final service = _MemoryDriverService();
    await openMenu(tester, service, stateError: true);
    expect(find.byType(Switch), findsNothing);
    expect(find.text(DriverHomeStrings.retryAction), findsOneWidget);
    expect(service.writes, 0);
  });

  testWidgets(
    'menu and confirmation remain usable on short screens with large text',
    (tester) async {
      final service = _MemoryDriverService();
      await openMenu(tester, service, textScale: 1.6);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text(DriverHomeStrings.offlineKeepAction),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(DriverHomeStrings.offlineKeepAction));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Tài khoản'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(DriverDrawer),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Tài khoản').hitTestable(), findsOneWidget);
      expect(service.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

class _MemoryDriverService extends DriverService {
  _MemoryDriverService()
    : super(
        client: SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        locationPublisher:
            ({
              required driverProfileId,
              required lat,
              required lng,
              heading,
              speed,
            }) async {},
      );
  bool online = true;
  bool fail = false;
  int writes = 0;

  @override
  Future<void> updateAvailability(bool value) async {
    writes++;
    if (fail) throw Exception('Chưa tắt được app');
    online = value;
  }

  @override
  Future<DriverModel?> getDriverByUserId(String userId) async => DriverModel(
    id: 'profile-1',
    userId: userId,
    isAvailable: online,
    updatedAt: DateTime.utc(2026, 9, 27),
    totalDeliveries: 0,
  );
}
