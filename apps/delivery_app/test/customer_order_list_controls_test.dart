import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:giaohang_design/giaohang_design.dart';
import 'package:delivery_app/features/customer/screens/order/order_widgets.dart';

void main() {
  testWidgets('orders header is visual-only and controls have clear surfaces', (
    tester,
  ) async {
    var created = false;
    var selectedIndex = 0;
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.bgLight,
          body: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: 375,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.screenH),
                  child: OrderCompactToolbar(
                    onCreateOrder: () => created = true,
                    controller: controller,
                    onSearchChanged: (_) {},
                    filters: const [
                      'Tất cả',
                      'Đang xử lý',
                      'Hoàn thành',
                      'Đã huỷ',
                    ],
                    filterIcons: const [
                      Icons.view_stream_rounded,
                      Icons.local_shipping_rounded,
                      Icons.task_alt_rounded,
                      Icons.cancel_rounded,
                    ],
                    selectedIndex: selectedIndex,
                    onFilterSelected: (index) {
                      setState(() => selectedIndex = index);
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    final header = tester.widget<Container>(find.byKey(orderVisualHeaderKey));
    final headerDecoration = header.decoration as BoxDecoration;
    expect(headerDecoration.color, AppColors.bgCard);
    expect(headerDecoration.border, isNotNull);
    expect(find.byType(Image), findsNothing);
    expect(tester.getSize(find.byKey(orderCompactToolbarKey)).height, 190);
    final headerRect = tester.getRect(find.byKey(orderVisualHeaderKey));
    final controlsRect = tester.getRect(find.byKey(orderControlsSurfaceKey));
    expect(headerRect.top, lessThan(controlsRect.top));
    expect(headerRect.bottom, controlsRect.top);
    expect(headerRect.left, controlsRect.left);
    expect(headerRect.right, controlsRect.right);
    expect(find.text('Đơn đã mua'), findsOneWidget);

    await tester.tap(find.byKey(orderCreateActionKey));
    expect(created, isTrue);

    final controls = tester.widget<Container>(
      find.byKey(orderControlsSurfaceKey),
    );
    final controlsDecoration = controls.decoration as BoxDecoration;
    expect(controlsDecoration.color, AppColors.bgCard);
    expect(controlsDecoration.border, isNotNull);
    expect(controlsDecoration.boxShadow, isNotEmpty);

    expect(find.text('Tất cả'), findsOneWidget);
    expect(find.byKey(orderFilterKey(1)), findsOneWidget);
    await tester.tap(find.byKey(orderFilterKey(1)));
    await tester.pump(AppDuration.normal);
    expect(selectedIndex, 1);
    expect(find.byKey(orderFilterKey(1)), findsOneWidget);
  });

  testWidgets('orders visual controls fit a small phone with large text', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.6),
          ),
          child: Scaffold(
            backgroundColor: AppColors.bgLight,
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: OrderCompactToolbar(
                onCreateOrder: () {},
                controller: controller,
                onSearchChanged: (_) {},
                filters: const ['Tất cả', 'Đang xử lý', 'Hoàn thành', 'Đã huỷ'],
                filterIcons: const [
                  Icons.view_stream_rounded,
                  Icons.local_shipping_rounded,
                  Icons.task_alt_rounded,
                  Icons.cancel_rounded,
                ],
                selectedIndex: 0,
                onFilterSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(orderCompactToolbarKey)).height, 190);
    expect(find.byKey(orderVisualHeaderKey), findsOneWidget);
    expect(find.byKey(orderControlsSurfaceKey), findsOneWidget);
  });
}
