import 'dart:convert';

import 'package:delivery_app/features/customer/screens/create_order/utils/order_form_validators.dart';
import 'package:delivery_app/features/customer/screens/create_order/utils/validate_order_form.dart';
import 'package:delivery_app/features/customer/screens/create_order/widgets/cargo_image_picker.dart';
import 'package:delivery_app/features/customer/screens/create_order/widgets/order_cargo_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  test('details require recipient, phone, cargo, category and photo', () {
    String? validate({
      String name = 'Nguyễn An',
      String phone = '0901234567',
      String item = 'Hồ sơ',
      String category = 'document',
      bool photo = true,
    }) => validateOrderDetails(
      recipientName: name,
      recipientPhone: phone,
      itemName: item,
      itemCategory: category,
      hasPhoto: photo,
    );
    expect(validate(), isNull);
    expect(validate(name: '  '), isNotNull);
    expect(validate(phone: ''), isNotNull);
    expect(validate(phone: '123'), isNotNull);
    expect(validate(item: '  '), isNotNull);
    expect(validate(category: ''), OrderFormValidationText.categoryRequired);
    expect(
      validate(category: 'unknown'),
      OrderFormValidationText.categoryRequired,
    );
    expect(validate(photo: false), OrderFormValidationText.photoRequired);
  });

  testWidgets('photo and category are required; description remains optional', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final name = TextEditingController();
    final description = TextEditingController();
    addTearDown(name.dispose);
    addTearDown(description.dispose);
    final form = GlobalKey<FormState>();
    var category = '';
    XFile? image;
    final photo = XFile.fromData(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
      name: 'cargo.png',
      mimeType: 'image/png',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                void choosePhoto() => setState(() => image = photo);
                return Form(
                  key: form,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        CreateOrderCargoSection(
                          itemNameController: name,
                          itemDescriptionController: description,
                          itemCategory: category,
                          requiredText: requiredOrderText,
                          onCategoryChanged: (value) =>
                              setState(() => category = value),
                        ),
                        CreateOrderPhotosSection(
                          image: image,
                          onPickCamera: choosePhoto,
                          onPickGallery: choosePhoto,
                          onRemove: () => setState(() => image = null),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    expect(validateOrderForm(form), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Danh mục *', findRichText: true), findsOneWidget);
    expect(find.text('Ảnh kiện hàng *', findRichText: true), findsOneWidget);
    expect(find.text(OrderFormValidationText.photoRequired), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Hồ sơ');
    await tester.ensureVisible(find.text('Tài liệu'));
    await tester.tap(find.text('Tài liệu'));
    await tester.pumpAndSettle();
    expect(form.currentState!.validate(), isFalse);
    tester
        .widget<CargoImagePicker>(find.byType(CargoImagePicker))
        .onPickGallery();
    await tester.pumpAndSettle();
    expect(description.text, isEmpty);
    expect(form.currentState!.validate(), isTrue);
    tester.widget<CargoImagePicker>(find.byType(CargoImagePicker)).onRemove();
    await tester.pumpAndSettle();
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text(OrderFormValidationText.photoRequired), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
