import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_mobile/core/models/recent_address_model.dart';
import 'package:giaohang_mobile/core/models/reverse_geocode_result.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/address_picker_strings.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/controllers/address_picker_controller.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/utils/address_search_result.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/map_picker_sheet.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/address_picker/map_address_tab.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/address_picker/pickup_reference_card.dart';
import 'package:latlong2/latlong.dart';

import 'helpers/utraffic_capture_fonts.dart';
import 'support/return_map_test_tiles.dart';

const pickup = MapPickerResult(
  position: LatLng(10.84562, 106.74594),
  formattedAddress: '19A Linh Đông, Thủ Đức, TP. Hồ Chí Minh',
  addressDetail: '',
  deliveryNote: 'Gọi trước khi lấy',
);
const delivery = MapPickerResult(
  position: LatLng(10.857, 106.757),
  formattedAddress: '25 Kha Vạn Cân, Thủ Đức, TP. Hồ Chí Minh',
  addressDetail: '',
  deliveryNote: 'Giao tại cổng',
);

void main() {
  setUpAll(() async {
    await prepareUtrafficCaptureFonts();
    await ReturnMapTestTiles.prepare();
  });

  testWidgets(
    'both endpoints are visible without moving the selected delivery or its details',
    (tester) async {
      final controller = AddressPickerController(
        initialPosition: delivery.position,
        initialSelection: delivery,
        pickupReferencePosition: pickup.position,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (_, _) => MapAddressTab(
                controller: controller,
                onLocate: () {},
                pickupSelection: pickup,
                tileProvider: ReturnMapTestTiles(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final camera = controller.mapController.camera;
      expect(camera.center, delivery.position);
      expect(camera.visibleBounds.contains(pickup.position), isTrue);
      expect(camera.visibleBounds.contains(delivery.position), isTrue);
      final layer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
      expect(layer.markers.single.point, pickup.position);
      expect(controller.buildResult().position, delivery.position);
      expect(controller.buildResult().deliveryNote, delivery.deliveryNote);
      final address = controller.buildResult().address;
      controller.mapController.move(delivery.position, 18);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(AddressPickerStrings.showBothStops));
      await tester.pumpAndSettle();
      expect(
        controller.mapController.camera.visibleBounds.contains(pickup.position),
        isTrue,
      );
      expect(controller.buildResult().position, delivery.position);
      expect(controller.buildResult().address, address);
      const searchedPosition = LatLng(10.87, 106.78);
      controller.selectSearchResult(
        const AddressSearchResult(
          position: searchedPosition,
          resolvedAddress: ReverseGeocodeResult(
            displayAddress: '12 Phạm Văn Đồng, TP. Hồ Chí Minh',
            rawDisplayName: '12 Phạm Văn Đồng, TP. Hồ Chí Minh',
            houseNumber: '12',
          ),
          displayAddress: '12 Phạm Văn Đồng, TP. Hồ Chí Minh',
          rawDisplayName: '12 Phạm Văn Đồng, TP. Hồ Chí Minh',
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.buildResult().position, searchedPosition);
      expect(controller.mapController.camera.center, searchedPosition);
      expect(
        controller.mapController.camera.visibleBounds.contains(pickup.position),
        isTrue,
      );
      expect(
        tester
            .widget<MarkerLayer>(find.byType(MarkerLayer))
            .markers
            .single
            .point,
        pickup.position,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  for (final config in [
    (const Size(390, 844), 1.0),
    (const Size(320, 568), 1.6),
    (const Size(844, 390), 1.0),
  ]) {
    testWidgets(
      'delivery sheet keeps pickup context and supports keyboard at ${config.$1}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = config.$1;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final boundary = GlobalKey();
        final keyboard = ValueNotifier<double>(0);
        addTearDown(keyboard.dispose);
        await tester.pumpWidget(
          ProviderScope(
            child: RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                home: Scaffold(
                  body: ValueListenableBuilder<double>(
                    valueListenable: keyboard,
                    builder: (context, inset, _) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(config.$2),
                        viewInsets: EdgeInsets.only(bottom: inset),
                      ),
                      child: MapPickerSheet(
                        initialPosition: delivery.position,
                        addressType: RecentAddressType.delivery,
                        initialSelection: delivery,
                        pickupSelection: pickup,
                        tileProvider: ReturnMapTestTiles(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PickupReferenceCard), findsOneWidget);
        expect(find.text(AddressPickerStrings.pickupSelected), findsOneWidget);
        expect(find.text(pickup.address), findsOneWidget);
        expect(
          find.byKey(const ValueKey('address-picker-pickup-marker')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        if (config.$1.width == 320) {
          await tester.tap(find.byType(PickupReferenceCard));
          await tester.pumpAndSettle();
          final mapRect = tester.getRect(find.byType(FlutterMap));
          final confirmRect = tester.getRect(
            find.byKey(const Key('address-picker-confirm-button')),
          );
          expect(mapRect.bottom, lessThanOrEqualTo(confirmRect.top));
          expect(tester.takeException(), isNull);
        }
        if (config.$1.width == 390 || config.$1.width == 320) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              config.$1.width == 390
                  ? '../../artifacts/delivery_picker_pickup_context.png'
                  : '../../artifacts/delivery_picker_pickup_context_320.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        if (config.$1.height > 500) {
          keyboard.value = 260;
          await tester.pumpAndSettle();
          expect(find.byType(PickupReferenceCard), findsNothing);
          expect(tester.takeException(), isNull);
          keyboard.value = 0;
          await tester.pumpAndSettle();
          tester
              .state<ScrollableState>(
                find
                    .descendant(
                      of: find.byType(CustomScrollView),
                      matching: find.byType(Scrollable),
                    )
                    .first,
              )
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          expect(find.byType(PickupReferenceCard), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'pickup and address-book editing do not show a previous order pickup',
    (tester) async {
      for (final saveOnly in [false, true]) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: MapPickerSheet(
                  key: ValueKey(saveOnly),
                  initialPosition: delivery.position,
                  addressType: RecentAddressType.pickup,
                  initialSelection: delivery,
                  pickupSelection: pickup,
                  saveOnly: saveOnly,
                  tileProvider: ReturnMapTestTiles(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PickupReferenceCard), findsNothing);
        expect(
          find.byKey(const ValueKey('address-picker-pickup-marker')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
