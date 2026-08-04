import 'package:delivery_app/core/services/osrm_service.dart';
import 'package:delivery_app/core/utils/delivery_eta_calculator.dart';
import 'package:delivery_app/core/utils/delivery_fee_calculator.dart';
import 'package:delivery_app/core/utils/delivery_pricing_policy.dart';
import 'package:delivery_app/features/customer/screens/create_order/utils/order_form_data.dart';
import 'package:delivery_app/features/customer/screens/create_order/widgets/delivery_quote_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeliveryPricingPolicy', () {
    test('base fee includes the first two kilometers', () {
      final quote = DeliveryPricingPolicy.calculate(distanceMeters: 2000);

      expect(quote.baseFee, 18000);
      expect(quote.standardBillableKm, 0);
      expect(quote.distanceFee, 0);
      expect(quote.total, 18000);
    });

    test('nine kilometers only charges distance after the included tier', () {
      final quote = DeliveryPricingPolicy.calculate(distanceMeters: 9000);

      expect(quote.standardBillableKm, 7);
      expect(quote.longBillableKm, 0);
      expect(quote.standardDistanceFee, 35000);
      expect(quote.total, 53000);
    });

    test('long-distance tier starts after ten kilometers', () {
      final quote = DeliveryPricingPolicy.calculate(distanceMeters: 12000);

      expect(quote.standardBillableKm, 8);
      expect(quote.longBillableKm, 2);
      expect(quote.standardDistanceFee, 40000);
      expect(quote.longDistanceFee, 8000);
      expect(quote.total, 66000);
    });

    test('rounds the final quote up to one thousand dong', () {
      final quote = DeliveryPricingPolicy.calculate(distanceMeters: 2150);

      expect(quote.total, 19000);
    });
  });

  group('DeliveryEtaCalculator', () {
    test(
      'rejects an implausible eight-minute OSRM ETA for nine kilometers',
      () {
        final eta = DeliveryEtaCalculator.calculate(
          distanceMeters: 9000,
          routeDurationSeconds: 8 * 60,
          quotedAt: DateTime(2026, 7, 29, 12),
        );

        expect(eta.usedRouteDuration, isFalse);
        expect(eta.minMinutes, 25);
        expect(eta.maxMinutes, 35);
      },
    );

    test('widens the estimate during a configured peak window', () {
      final eta = DeliveryEtaCalculator.calculate(
        distanceMeters: 9000,
        routeDurationSeconds: 8 * 60,
        quotedAt: DateTime(2026, 7, 29, 17, 30),
      );

      expect(eta.isPeakHour, isTrue);
      expect(eta.minMinutes, 30);
      expect(eta.maxMinutes, 40);
    });

    test('keeps a plausible OSRM duration as an input signal', () {
      final eta = DeliveryEtaCalculator.calculate(
        distanceMeters: 9000,
        routeDurationSeconds: 20 * 60,
        quotedAt: DateTime(2026, 7, 29, 12),
      );

      expect(eta.usedRouteDuration, isTrue);
      expect(eta.calibratedTravelMinutes, closeTo(22, 0.001));
      expect(eta.rangeLabel, '25–35 phút');
    });
  });

  test('DeliveryFeeCalculator returns one coherent route quote', () async {
    final quote = await DeliveryFeeCalculator.estimate(
      pickupLat: 11.0,
      pickupLng: 106.6,
      deliveryLat: 11.05,
      deliveryLng: 106.65,
      serviceType: 'standard',
      osrm: _NineKilometerOsrm(),
      quotedAt: DateTime(2026, 7, 29, 12),
    );

    expect(quote.source, 'osrm');
    expect(quote.distanceKm, 9);
    expect(quote.deliveryFee, 53000);
    expect(quote.eta.usedRouteDuration, isFalse);
    expect(quote.eta.rangeLabel, '25–35 phút');
  });

  testWidgets('quote card presents ETA and an auditable price breakdown', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fee = DeliveryPricingPolicy.calculate(distanceMeters: 9000);
    final eta = DeliveryEtaCalculator.calculate(
      distanceMeters: 9000,
      routeDurationSeconds: 8 * 60,
      quotedAt: DateTime(2026, 7, 29, 12),
    );
    final data = OrderFormData(
      pickupAddress: 'Điểm lấy hàng',
      pickupLat: 11,
      pickupLng: 106.6,
      deliveryAddress: 'Điểm giao hàng',
      deliveryLat: 11.05,
      deliveryLng: 106.65,
      senderName: 'Người gửi',
      senderPhone: '0900000000',
      recipientName: 'Người nhận',
      recipientPhone: '0911111111',
      note: '',
      itemName: 'Tài liệu',
      itemCategory: 'document',
      itemDescription: '',
      cargoImage: null,
      paymentMethod: 'cash',
      deliveryFee: fee.total,
      totalPrice: fee.total,
      distanceMeters: 9000,
      durationSeconds: 8 * 60,
      distanceSource: 'osrm',
      feeBreakdown: fee,
      deliveryEta: eta,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: DeliveryQuoteCard(data: data),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Giao hàng dự kiến'), findsOneWidget);
    expect(find.text('25–35 phút'), findsOneWidget);
    expect(find.text('9.0 km đường bộ'), findsOneWidget);
    expect(find.text('Tìm tài xế tối đa 15 phút'), findsOneWidget);
    expect(find.text('CHI TIẾT CƯỚC PHÍ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _NineKilometerOsrm extends OsrmService {
  @override
  Future<OsrmRouteResult?> getRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    return const OsrmRouteResult(
      points: [],
      distanceMeters: 9000,
      durationSeconds: 8 * 60,
    );
  }
}
