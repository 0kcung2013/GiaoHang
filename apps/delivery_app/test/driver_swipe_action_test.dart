import 'package:delivery_app/features/driver/widgets/driver_swipe_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_design/giaohang_design.dart';

void main() {
  testWidgets('requires a deliberate horizontal swipe', (tester) async {
    var completionCount = 0;
    await tester.pumpWidget(_testApp(onCompleted: () => completionCount++));

    await tester.drag(
      find.byKey(const Key('test-driver-swipe')),
      const Offset(70, 0),
    );
    await tester.pumpAndSettle();
    expect(completionCount, 0);

    await _completeSwipe(tester, find.byKey(const Key('test-driver-swipe')));
    expect(completionCount, 1);
  });

  testWidgets('uses project typography and intact Vietnamese Unicode', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(onCompleted: () {}, textScaler: const TextScaler.linear(1.6)),
    );

    final label = tester.widget<Text>(find.text('Gạt đã giao'));
    expect(label.data, isNot(contains('\uFFFD')));
    expect(label.style?.fontFamily, AppTextStyles.labelLarge.fontFamily);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _completeSwipe(WidgetTester tester, Finder finder) async {
  final rect = tester.getRect(finder);
  final gesture = await tester.startGesture(
    Offset(rect.left + 24, rect.center.dy),
  );
  await gesture.moveTo(Offset(rect.right - 24, rect.center.dy));
  await gesture.up();
  await tester.pumpAndSettle();
}

Widget _testApp({
  required VoidCallback onCompleted,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: 340,
            child: DriverSwipeAction(
              key: const Key('test-driver-swipe'),
              label: 'Gạt đã giao',
              accent: AppColors.success,
              icon: Icons.check_rounded,
              onCompleted: onCompleted,
            ),
          ),
        ),
      ),
    ),
  );
}
