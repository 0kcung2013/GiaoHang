import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:operations_web/features/support/data/support_order_context_repository.dart';
import 'package:operations_web/features/support/widgets/support_order_context.dart';
import 'package:operations_web/features/support_orders/utils/support_order_information_strings.dart';
import 'package:operations_web/features/support_orders/widgets/support_order_information.dart';

void main() {
  test(
    'shared snapshot keeps cargo, contacts, payments and current-driver ETA',
    () {
      final order = _order();
      expect(order.itemWeightKg, 2.75);
      expect(order.goodsValue, 200000);
      expect(order.customer?.phone, '0901234567');
      expect(order.driver?.email, 'driver@example.invalid');
      expect(order.predictedDeliveryAt, DateTime.parse('2026-10-11T01:35:00Z'));
      expect(RiskOrderSummary.fromJson(order.toJson()).itemWeightKg, 2.75);
      final stale = RiskOrderSummary.fromJson({
        ...order.toJson(),
        'driver_id': 'new-driver',
      });
      expect(stale.predictedDeliveryAt, isNull);
    },
  );

  for (final viewport in [
    (size: const Size(320, 568), scale: 1.6),
    (size: const Size(882, 849), scale: 1.0),
    (size: const Size(1280, 850), scale: 1.0),
  ]) {
    testWidgets(
      'complete order information fits ${viewport.size} text ${viewport.scale}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = viewport.size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(viewport.scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SupportOrderInformation(order: _order()),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final text in [
          '2,75 kg',
          'Hộp bánh sinh nhật',
          'Nguyễn Người Gửi',
          'Trần Người Nhận',
          'Lê Tài Xế',
          '0901234567',
          '0907654321',
          '0988888888',
          'sender@example.invalid',
          'driver@example.invalid',
          SupportOrderInformationStrings.receiverCollection,
          SupportOrderInformationStrings.driverAdvance,
          SupportOrderInformationStrings.predicted,
          SupportOrderInformationStrings.deadline,
        ]) {
          expect(find.text(text), findsOneWidget, reason: text);
        }
        expect(
          find.text('Không xếp nghiêng; gọi trước khi đến.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('legacy weight is unknown and missing driver stays explicit', (
    tester,
  ) async {
    final legacy = RiskOrderSummary.fromJson({
      ..._order().toJson(),
      'item_weight_kg': null,
      'item_category': null,
      'driver': null,
      'driver_id': null,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SupportOrderInformation(order: legacy),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa khai báo'), findsNWidgets(2));
    expect(find.text('0 kg'), findsNothing);
    expect(find.text(SupportOrderInformationStrings.noDriver), findsOneWidget);
    expect(
      find.text(SupportOrderInformationStrings.awaitingDriver),
      findsOneWidget,
    );
  });

  testWidgets(
    'ticket failure leaves full order visible and blocks creating a duplicate conversation',
    (tester) async {
      final repository = _ContextRepository(
        data: SupportOrderContextData(order: _order(), ticketLoadFailed: true),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SupportOrderContext(
                orderId: 'order',
                repository: repository,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2,75 kg'), findsOneWidget);
      expect(find.text('Nguyễn Người Gửi'), findsOneWidget);
      expect(
        find.text(SupportOrderInformationStrings.ticketLoadError),
        findsOneWidget,
      );
      expect(
        find.text(SupportOrderInformationStrings.contactCustomer),
        findsNothing,
      );
      expect(
        find.text(SupportOrderInformationStrings.contactDriver),
        findsNothing,
      );
    },
  );

  testWidgets('context reload recovers order load error', (tester) async {
    final repository = _ContextRepository(
      data: SupportOrderContextData(order: _order()),
      failFirst: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SupportOrderContext(
              orderId: 'order',
              repository: repository,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(SupportOrderInformationStrings.loadError), findsOneWidget);
    await tester.tap(find.text(SupportOrderInformationStrings.reload));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    expect(find.text('2,75 kg'), findsOneWidget);
    expect(
      find.text(SupportOrderInformationStrings.contactCustomer),
      findsOneWidget,
    );
    expect(
      find.text(SupportOrderInformationStrings.contactDriver),
      findsOneWidget,
    );
  });
}

RiskOrderSummary _order() => RiskOrderSummary.fromJson({
  'id': 'order',
  'tracking_code': 'GH-10205',
  'status': 'picking_up',
  'customer_id': 'sender',
  'driver_id': 'driver',
  'pickup_address': '23 Đường ĐX124, Khu phố Tân An 3, Thành phố Hồ Chí Minh',
  'pickup_lat': 10.78,
  'pickup_lng': 106.68,
  'delivery_address':
      '12 Đại lộ Bình Dương, Khu phố Định Hòa 1, Thành phố Hồ Chí Minh',
  'delivery_lat': 10.80,
  'delivery_lng': 106.71,
  'customer': {
    'full_name': 'Nguyễn Người Gửi',
    'phone': '0901234567',
    'email': 'sender@example.invalid',
  },
  'driver': {
    'full_name': 'Lê Tài Xế',
    'phone': '0988888888',
    'email': 'driver@example.invalid',
  },
  'recipient_name': 'Trần Người Nhận',
  'recipient_phone': '0907654321',
  'item_name': 'Hộp bánh sinh nhật',
  'item_category': 'food',
  'item_weight_kg': '2.750',
  'item_description': 'Hộp bánh lớn, giữ thẳng khi di chuyển.',
  'note': 'Không xếp nghiêng; gọi trước khi đến.',
  'goods_value': '200000',
  'cod_collection_amount': 150000,
  'delivery_fee': 25000,
  'total_price': 175000,
  'driver_advance_amount': 150000,
  'receiver_collection_amount': 175000,
  'driver_net_earning': 25000,
  'delivery_fee_payer': 'recipient',
  'payment_method': 'cash',
  'payment_status': 'not_required',
  'service_type': 'standard',
  'created_at': '2026-10-11T01:00:00Z',
  'updated_at': '2026-10-11T01:10:00Z',
  'estimated_delivery_at': '2026-10-11T02:00:00Z',
  'delivery_eta': {
    'driver_id': 'driver',
    'predicted_at': '2026-10-11T01:35:00Z',
  },
});

class _ContextRepository implements SupportOrderContextRepository {
  _ContextRepository({required this.data, this.failFirst = false});
  final SupportOrderContextData data;
  final bool failFirst;
  int calls = 0;
  @override
  Future<SupportOrderContextData> fetch(String orderId) async {
    calls++;
    if (failFirst && calls == 1) throw StateError('Fixture load error');
    return data;
  }
}
