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

  testWidgets('fills a loose form and clips the thumb at the right endpoint', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(onCompleted: () {}, width: 240, dark: true, loose: true),
    );

    final action = find.byKey(const Key('test-driver-swipe'));
    final track = tester.widget<AnimatedContainer>(
      find.byKey(const Key('driver-swipe-track')),
    );
    expect(track.clipBehavior, Clip.antiAlias);

    final rect = tester.getRect(action);
    final gesture = await tester.startGesture(
      Offset(rect.left + 24, rect.center.dy),
    );
    await gesture.moveTo(Offset(rect.right + 80, rect.center.dy));
    await tester.pump();

    final trackRect = tester.getRect(
      find.byKey(const Key('driver-swipe-track')),
    );
    expect(trackRect.width, 240);
    final thumbRect = tester.getRect(
      find.byKey(const Key('driver-swipe-thumb')),
    );
    expect(
      thumbRect.right,
      lessThanOrEqualTo(trackRect.right - AppSpacing.sm + 1),
    );

    await gesture.up();
    await tester.pump(AppDuration.fast);
    await tester.pumpAndSettle();
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
  double width = 340,
  bool dark = false,
  bool loose = false,
}) {
  final action = DriverSwipeAction(
    key: const Key('test-driver-swipe'),
    label: 'Gạt đã giao',
    accent: AppColors.success,
    icon: Icons.check_rounded,
    dark: dark,
    onCompleted: onCompleted,
  );
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: loose
                ? Column(mainAxisSize: MainAxisSize.min, children: [action])
                : action,
          ),
        ),
      ),
    ),
  );
}
