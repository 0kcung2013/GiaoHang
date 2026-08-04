import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:giaohang_design/giaohang_design.dart';
import 'package:delivery_app/features/customer/screens/create_order/widgets/create_order_form_sections.dart';
import 'package:delivery_app/features/customer/screens/create_order/widgets/create_order_header.dart';
import 'package:delivery_app/features/customer/screens/create_order/widgets/create_order_inputs.dart';
import 'package:delivery_app/features/customer/screens/create_order/widgets/create_order_options.dart';

void main() {
  testWidgets('create order form uses premium white orange surfaces', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var selectedCategory = 'food';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.bgLight,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    const CreateOrderHeader(),
                    const SizedBox(height: AppSpacing.lg),
                    CreateOrderSection(
                      step: '02',
                      icon: Icons.person_outline_rounded,
                      title: 'Người nhận',
                      subtitle: 'Thông tin liên hệ khi giao hàng',
                      children: [
                        CreateOrderTextField(
                          controller: controller,
                          label: 'Họ và tên',
                          hint: 'Nhập tên người nhận',
                          icon: Icons.person_outline_rounded,
                          requiredField: true,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        CargoCategorySelector(
                          value: selectedCategory,
                          onChanged: (value) {
                            setState(() => selectedCategory = value);
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    final header = tester.widget<Container>(find.byKey(createOrderHeaderKey));
    final headerDecoration = header.decoration as BoxDecoration;
    expect(headerDecoration.color, AppColors.bgCard);

    final section = tester.widget<Container>(
      find.byKey(createOrderSectionCardKey),
    );
    final sectionDecoration = section.decoration as BoxDecoration;
    expect(sectionDecoration.color, AppColors.bgCard);
    expect(sectionDecoration.boxShadow, AppShadow.subtle);

    final textField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(createOrderTextFieldKey),
        matching: find.byType(TextField),
      ),
    );
    final inputDecoration = textField.decoration!;
    expect(inputDecoration.fillColor, AppColors.bgLight);
    expect(
      (inputDecoration.focusedBorder as OutlineInputBorder).borderSide.color,
      AppColors.accent,
    );
    expect(find.text('•'), findsOneWidget);

    await tester.tap(find.text('Tài liệu'));
    await tester.pumpAndSettle();
    expect(selectedCategory, 'document');
    expect(find.byKey(cargoCategoryOptionKey), findsNWidgets(6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('route fields stay readable on a narrow mobile screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pickupController = TextEditingController(
      text: '12 Nguyễn Trãi, Quận 1',
    );
    final deliveryController = TextEditingController();
    addTearDown(pickupController.dispose);
    addTearDown(deliveryController.dispose);
    var deliveryTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.bgLight,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            child: CreateOrderAddressSection(
              pickupAddressController: pickupController,
              deliveryAddressController: deliveryController,
              requiredAddress: (_) =>
                  (_) => null,
              onPickPickup: () {},
              onPickDelivery: () => deliveryTapped = true,
              hasPickupPin: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Điểm lấy hàng'), findsOneWidget);
    expect(find.text('Điểm giao hàng'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);

    await tester.tap(find.byType(TextFormField).at(1));
    expect(deliveryTapped, isTrue);
    expect(tester.takeException(), isNull);
  });
}
