import 'package:delivery_app/features/customer/screens/create_order/controllers/order_finance_form_controller.dart';
import 'package:delivery_app/features/customer/screens/create_order/widgets/order_finance_details_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('customer enters the COD amount to collect', (tester) async {
    final controller = OrderFinanceFormController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OrderFinanceDetailsSection(
              codCollectionController: controller.codCollectionController,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Thu tiền hộ'), findsOneWidget);
    expect(find.text('Số tiền thu hộ (COD)'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '120000');

    expect(controller.codCollectionAmount, 120000);
  });

  testWidgets('COD is required and capped at two million', (tester) async {
    final controller = OrderFinanceFormController();
    final formKey = GlobalKey<FormState>();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: OrderFinanceDetailsSection(
              codCollectionController: controller.codCollectionController,
            ),
          ),
        ),
      ),
    );

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Vui lòng nhập số tiền cần thu hộ.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '2.500.000');
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Tiền thu hộ tối đa 2.000.000đ.'), findsOneWidget);
  });

  test('finance form ignores COD formatting characters', () {
    final controller = OrderFinanceFormController();
    addTearDown(controller.dispose);

    controller.codCollectionController.text = '1.250.000đ';

    expect(controller.codCollectionAmount, 1250000);
  });
}
