import 'package:delivery_app/features/driver/screens/account/models/driver_account_view_data.dart';
import 'package:delivery_app/features/driver/screens/account/widgets/driver_account_profile_hero.dart';
import 'package:delivery_app/features/driver/screens/account/widgets/driver_account_sections.dart';
import 'package:delivery_app/features/driver/screens/account/widgets/driver_profile_change_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  const data = DriverAccountViewData(
    driverId: 'driver-12345678',
    name: 'Nguyễn Minh Tài',
    email: 'tai.xe@example.com',
    phone: '0901234567',
    avatarUrl: null,
    isAvailable: true,
    approvalStatus: 'approved',
    totalDeliveries: 128,
    vehicleType: 'motorbike',
    vehicleBrandModel: 'Honda Air Blade',
    vehicleColor: 'Đen nhám',
    licensePlate: '59-X1 123.45',
    hasIdentityCard: true,
    hasDriverLicense: true,
    hasVehiclePhoto: false,
  );

  testWidgets('account sections remain stable with large text on mobile', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        SingleChildScrollView(
          child: Column(
            children: const [
              DriverAccountProfileHero(data: data),
              SizedBox(height: 24),
              DriverVehicleCard(data: data),
              SizedBox(height: 24),
              DriverVerificationCard(data: data),
              SizedBox(height: 24),
              DriverContactCard(data: data),
            ],
          ),
        ),
        textScale: 1.6,
      ),
    );

    expect(find.text('Nguyễn Minh Tài'), findsOneWidget);
    expect(find.text('ĐÃ XÁC MINH'), findsOneWidget);
    expect(find.text('Honda Air Blade'), findsOneWidget);
    expect(find.text('59-X1 123.45'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'driver account never renders rating and exposes one edit request CTA',
    (tester) async {
      await tester.pumpWidget(
        _testApp(
          SingleChildScrollView(
            child: Column(
              children: [
                const DriverAccountProfileHero(data: data),
                DriverProfileChangeAction(
                  request: null,
                  onCreate: () {},
                  onView: (_) {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Đánh giá'), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.text('4.9'), findsNothing);
      expect(find.text('Yêu cầu chỉnh sửa hồ sơ'), findsOneWidget);
    },
  );

  testWidgets('pending request replaces create CTA at large text scale', (
    tester,
  ) async {
    final request = DriverProfileChangeRequest.fromJson({
      'id': 'request-1',
      'driver_id': 'driver-12345678',
      'requested_by': 'user-1',
      'current_snapshot': {'phone': '0901234567'},
      'requested_changes': {'phone': '0911111111'},
      'reason': 'Đổi số liên hệ',
      'status': 'pending',
      'created_at': '2026-08-24T03:00:00Z',
      'updated_at': '2026-08-24T03:00:00Z',
    });

    await tester.pumpWidget(
      _testApp(
        SingleChildScrollView(
          child: DriverProfileChangeAction(
            request: request,
            onCreate: () {},
            onView: (_) {},
          ),
        ),
        textScale: 1.6,
      ),
    );

    expect(find.text('Xem yêu cầu đang chờ'), findsOneWidget);
    expect(find.text('Yêu cầu chỉnh sửa hồ sơ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('logout action keeps a full-width accessible target', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      _testApp(
        DriverAccountLogoutButton(
          isSigningOut: false,
          onTap: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.text('Đăng xuất'));

    expect(tapped, isTrue);
    expect(tester.getSize(find.byType(DriverAccountLogoutButton)).height, 54);
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp(Widget child, {double textScale = 1}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Center(child: SizedBox(width: 375, child: child)),
      ),
    ),
  );
}
