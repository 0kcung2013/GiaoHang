import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/providers/customer_providers.dart';
import 'package:delivery_app/features/driver/screens/navigation/driver_accepted_order_screen.dart';
import 'package:delivery_app/core/utils/money_formatter.dart';
import 'package:delivery_app/core/widgets/order_cargo_info_block.dart';
import 'package:delivery_app/core/widgets/stored_media_image.dart';
import 'package:delivery_app/features/driver/screens/home/widgets/driver_order_card.dart';
import 'package:delivery_app/features/driver/screens/home/widgets/driver_order_offer_summary.dart';
import 'package:delivery_app/features/driver/screens/home/widgets/driver_incoming_offer_presentation.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_navigation_view.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_order_details_content.dart';
import 'package:delivery_app/features/driver/widgets/driver_swipe_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('acceptance navigation survives Realtime removing the offer', (
    tester,
  ) async {
    late VoidCallback openAccepted;
    late StateSetter update;
    var showOffer = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [orderByIdProvider.overrideWith((ref, id) async => null)],
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Scaffold(
                body: showOffer
                    ? Builder(
                        builder: (context) {
                          openAccepted = prepareDriverAcceptedOrderNavigation(
                            context,
                            'order-1',
                          );
                          return const Text('Offer');
                        },
                      )
                    : const SizedBox(),
              );
            },
          ),
        ),
      ),
    );
    update(() => showOffer = false);
    await tester.pump();
    openAccepted();
    await tester.pumpAndSettle();
    expect(find.byType(DriverAcceptedOrderScreen), findsOneWidget);
    expect(find.text(DriverOrderPresentationStrings.loadError), findsOneWidget);
    expect(find.text(_order().itemName!), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final status in ['pending', 'confirmed']) {
    testWidgets('$status cards hide cargo and show net earnings', (
      tester,
    ) async {
      final order = _order().copyWith(status: status);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: DriverOrderCard(order: order)),
            ),
          ),
        ),
      );
      expect(find.text(formatVnd(order.driverNetEarning)), findsOneWidget);
      expect(find.text(formatVnd(order.deliveryFee)), findsNothing);
      expect(find.text(order.itemName!), findsNothing);
      expect(find.text(order.itemDescription!), findsNothing);
      expect(find.byType(OrderCargoInfoBlock), findsNothing);
      expect(find.byType(StoredMediaImage), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'MAP and back keep the map mounted and the delivery action intact',
    (tester) async {
      var mapMounts = 0;
      var exits = 0;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: DriverNavigationView(
              showOrderDetails: true,
              order: _order(),
              map: _MapProbe(onMount: () => mapMounts++),
              arrivedAtTarget: false,
              isUpdatingStatus: false,
              onBack: () => exits++,
              onFitMap: () {},
              onPrimaryAction: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(DriverOrderDetailsContent), findsOneWidget);
      expect(find.text(_order().itemName!), findsOneWidget);
      expect(find.byType(StoredMediaImage), findsOneWidget);
      final action = tester.state(find.byType(DriverSwipeAction));
      expect(mapMounts, 1);

      await tester.tap(find.byKey(const ValueKey('driver-open-map')));
      await tester.pump();
      expect(find.byType(DriverOrderDetailsContent), findsNothing);
      expect(find.byKey(const ValueKey('map-probe')), findsOneWidget);
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pump();
      expect(find.byType(DriverOrderDetailsContent), findsOneWidget);
      expect(mapMounts, 1);
      expect(tester.state(find.byType(DriverSwipeAction)), same(action));
      expect(exits, 0);
      await tester.tap(find.byTooltip('Quay lại'));
      expect(exits, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('offer and details fit $size at text scale $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        Widget wrap(Widget child) => ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: child,
            ),
          ),
        );
        await tester.pumpWidget(
          wrap(
            DriverIncomingOfferPresentation(
              order: _order(),
              pickupDistanceMeters: 1200,
              actions: FilledButton(
                onPressed: () {},
                child: const Text('Nhận đơn'),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text(_order().itemName!), findsNothing);
        await tester.pumpWidget(
          wrap(
            DriverNavigationView(
              showOrderDetails: true,
              order: _order(),
              map: const ColoredBox(color: Colors.white),
              arrivedAtTarget: false,
              isUpdatingStatus: false,
              onBack: () {},
              onFitMap: () {},
              onPrimaryAction: () {},
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
          tester
              .getRect(
                find.byKey(const Key('driver-navigation-primary-action')),
              )
              .bottom,
          lessThanOrEqualTo(size.height),
        );
        await tester.tap(find.byKey(const ValueKey('driver-open-map')));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('missing cargo uses an explicit empty state', (tester) async {
    final order = OrderModel.fromJson({
      ..._order().toJson(),
      'item_name': null,
      'item_category': null,
      'item_description': null,
      'item_image_url': null,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DriverOrderDetailsContent(order: order)),
      ),
    );
    expect(
      find.text(DriverOrderPresentationStrings.emptyCargo),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

OrderModel _order() => OrderModel(
  id: 'order-1',
  customerId: 'customer-1',
  driverId: 'driver-1',
  status: 'assigned',
  trackingCode: 'GH-001',
  pickupAddress: '781 Nguyễn Chí Thanh, phường Tân An, Thủ Dầu Một',
  pickupLat: 10.773,
  pickupLng: 106.703,
  deliveryAddress:
      'Hẻm Lò Heo, đường Tân Định 041, khu phố 2, Bến Cát, Bình Dương',
  deliveryLat: 10.771,
  deliveryLng: 106.698,
  itemName: 'Hộp bánh sinh nhật',
  itemCategory: 'food',
  itemDescription:
      'Giữ hộp thẳng đứng khi vận chuyển. Không đặt vật nặng lên trên.',
  itemImageUrl: 'https://example.com/cargo.png',
  note: 'Gọi người nhận trước khi đến.',
  deliveryFee: 50000,
  driverNetEarning: 42500,
  driverAdvanceAmount: 150000,
  receiverCollectionAmount: 200000,
  serviceType: 'standard',
  paymentMethod: 'cash',
  createdAt: DateTime(2026, 10, 8),
  updatedAt: DateTime(2026, 10, 8),
);

class _MapProbe extends StatefulWidget {
  const _MapProbe({required this.onMount});
  final VoidCallback onMount;
  @override
  State<_MapProbe> createState() => _MapProbeState();
}

class _MapProbeState extends State<_MapProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(key: ValueKey('map-probe'), color: Colors.white);
}
