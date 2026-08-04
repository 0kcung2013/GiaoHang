import 'package:delivery_app/core/models/saved_address_model.dart';
import 'package:delivery_app/features/customer/screens/create_order/address_picker_strings.dart';
import 'package:delivery_app/features/customer/screens/create_order/controllers/address_picker_controller.dart';
import 'package:delivery_app/features/customer/screens/create_order/widgets/address_picker/address_picker_tabs.dart';
import 'package:delivery_app/features/customer/screens/create_order/widgets/address_picker/save_address_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('address picker exposes map, saved and recent tabs', (
    tester,
  ) async {
    var selected = AddressPickerTab.map;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AddressPickerTabs(
              value: selected,
              onChanged: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    expect(find.text(AddressPickerStrings.mapTab), findsOneWidget);
    expect(find.text(AddressPickerStrings.savedTab), findsOneWidget);
    expect(find.text(AddressPickerStrings.recentTab), findsOneWidget);

    await tester.tap(find.text(AddressPickerStrings.savedTab));
    await tester.pumpAndSettle();
    expect(selected, AddressPickerTab.saved);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom saved-address label is progressively disclosed', (
    tester,
  ) async {
    final customController = TextEditingController();
    addTearDown(customController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SaveAddressSection(
              enabled: true,
              labelType: SavedAddressLabelType.other,
              customLabelController: customController,
              onEnabledChanged: (_) {},
              onLabelChanged: (_) {},
              onCustomLabelChanged: (_) {},
              customLabelError: AddressPickerStrings.customLabelRequired,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(saveAddressSwitchKey), findsOneWidget);
    expect(find.text(AddressPickerStrings.customLabelHint), findsOneWidget);
    expect(find.text(AddressPickerStrings.customLabelRequired), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
