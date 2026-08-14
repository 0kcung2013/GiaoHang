import 'package:delivery_app/features/driver/screens/widgets/driver_gps_debug_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_design/giaohang_design.dart';

void main() {
  Widget app(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('coordinate card shows an address without numeric coordinates', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const DriverGpsCoordinateCard(
          icon: Icons.my_location_rounded,
          color: AppColors.info,
          title: 'GPS thiết bị',
          subtitle: 'Vị trí thật do thiết bị cung cấp',
          address: '12 Nguyễn Huệ, Bến Nghé, Quận 1, TP.HCM',
        ),
      ),
    );

    expect(
      find.text('12 Nguyễn Huệ, Bến Nghé, Quận 1, TP.HCM'),
      findsOneWidget,
    );
    expect(find.textContaining('10.779000'), findsNothing);
    expect(find.textContaining('106.676500'), findsNothing);
  });

  testWidgets('coordinate cards show loading and unavailable messages', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const Column(
          children: [
            DriverGpsCoordinateCard(
              icon: Icons.my_location_rounded,
              color: AppColors.info,
              title: 'GPS thiết bị',
              subtitle: 'Vị trí thật do thiết bị cung cấp',
              address: 'Đang xác định địa chỉ…',
            ),
            DriverGpsCoordinateCard(
              icon: Icons.cloud_off_rounded,
              color: AppColors.warning,
              title: 'Đang lưu trên Supabase',
              subtitle: 'Chưa có vị trí trong hồ sơ tài xế',
              address: 'Không xác định được địa chỉ',
            ),
          ],
        ),
      ),
    );

    expect(find.text('Đang xác định địa chỉ…'), findsOneWidget);
    expect(find.text('Không xác định được địa chỉ'), findsOneWidget);
  });
}
