import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:delivery_app/features/driver/screens/home/driver_home_strings.dart';
import 'package:delivery_app/features/driver/screens/home/widgets/availability_toggle_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('availability control only shows status and switch', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(375, 812));

    await tester.pumpWidget(
      _AvailabilityPreview(
        driver: _driver(isAvailable: true),
        hasActiveOrder: false,
        textScaler: TextScaler.noScaling,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(DriverHomeStrings.activityLabel), findsOneWidget);
    expect(find.text(DriverHomeStrings.activityOnline), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('Sẵn sàng nhận đơn'), findsNothing);
    expect(
      find.text('Vị trí được cập nhật để ưu tiên đơn gần bạn.'),
      findsNothing,
    );
    expect(
      tester.getSize(find.byType(AvailabilityToggleCard)).height,
      lessThanOrEqualTo(96),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact availability control supports large text', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(375, 812));

    await tester.pumpWidget(
      _AvailabilityPreview(
        driver: _driver(isAvailable: true),
        hasActiveOrder: true,
        textScaler: TextScaler.linear(1.6),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(DriverHomeStrings.activityBusy), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setTestViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

DriverModel _driver({required bool isAvailable}) {
  return DriverModel(
    id: 'driver-profile-1',
    userId: 'driver-user-1',
    isAvailable: isAvailable,
    updatedAt: DateTime(2026, 7, 30),
    totalDeliveries: 12,
  );
}

class _AvailabilityPreview extends StatelessWidget {
  const _AvailabilityPreview({
    required this.driver,
    required this.hasActiveOrder,
    required this.textScaler,
  });

  final DriverModel driver;
  final bool hasActiveOrder;
  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: Scaffold(
                body: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: AvailabilityToggleCard(
                      driver: driver,
                      hasActiveOrder: hasActiveOrder,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
