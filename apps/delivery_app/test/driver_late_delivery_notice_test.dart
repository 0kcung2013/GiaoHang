import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:delivery_app/features/driver/screens/navigation/models/driver_late_delivery_notice.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_late_delivery_notice_dialog.dart';

void main() {
  test('uses server window and excludes previously consumed batches', () {
    final end = DateTime.utc(2026, 10, 2, 12);
    Map<String, dynamic> row(String id, String title, DateTime at) => {
      'order_id': id,
      'title': title,
      'created_at': at.toIso8601String(),
    };
    final logs = [
      row(
        'old',
        DriverLateDeliveryNotice.recordedTitle,
        end.subtract(const Duration(hours: 3)),
      ),
      row(
        'used',
        DriverLateDeliveryNotice.recordedTitle,
        end.subtract(const Duration(hours: 1)),
      ),
      row(
        'used',
        DriverLateDeliveryNotice.consumedTitle,
        end.subtract(const Duration(minutes: 50)),
      ),
      for (final id in ['a', 'b', 'c']) ...[
        row(id, DriverLateDeliveryNotice.recordedTitle, end),
        row(id, DriverLateDeliveryNotice.consumedTitle, end),
      ],
      row(
        'future',
        DriverLateDeliveryNotice.recordedTitle,
        end.add(const Duration(seconds: 1)),
      ),
    ];
    final notice = DriverLateDeliveryNotice.fromLogs(logs, end);
    expect(notice.count, 3);
    expect(notice.lockTriggered, true);
  });

  for (final size in [const Size(320, 480), const Size(390, 844)]) {
    testWidgets('warning and lock fit $size at large text scale', (
      tester,
    ) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const Scaffold();
            },
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
        ),
      );
      for (final count in [1, 2, 3]) {
        showDriverLateDeliveryNoticeDialog(
          context,
          DriverLateDeliveryNotice(count: count, lockTriggered: count == 3),
        );
        await tester.pumpAndSettle();
        expect(find.text('$count/3 đơn giao muộn'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Đã hiểu'));
        await tester.tap(find.text('Đã hiểu'));
        await tester.pumpAndSettle();
      }
    });
  }
}
