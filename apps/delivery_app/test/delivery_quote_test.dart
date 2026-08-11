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
    test('uses TP.HCM traffic AI when coordinates are supported', () {
      final eta = _hcmEta(quotedAt: DateTime(2026, 7, 29, 17, 30));

      expect(eta.usedRouteDuration, isTrue);
      expect(eta.usedAiCorrection, isTrue);
      expect(eta.aiModelVersion, 'hcm_utraffic_lgbm_v2_road_profile');
      expect(eta.aiDatasetLabel, 'UTraffic TP.HCM');
      expect(eta.aiUsesRealtimeTraffic, isFalse);
      expect(eta.aiTrafficMultiplier, greaterThanOrEqualTo(1));
      expect(
        eta.calibratedTravelMinutes,
        greaterThanOrEqualTo(eta.baselineTravelMinutes),
      );
      expect(eta.aiFallbackReason, isNull);
    });

    test('does not extrapolate the TP.HCM model to Bình Dương', () {
      final eta = DeliveryEtaCalculator.calculate(
        distanceMeters: 9000,
        routeDurationSeconds: 20 * 60,
        pickupLat: 11.05,
        pickupLng: 106.66,
        deliveryLat: 11.10,
        deliveryLng: 106.70,
        quotedAt: DateTime(2026, 7, 29, 17, 30),
      );

      expect(eta.usedRouteDuration, isTrue);
      expect(eta.usedAiCorrection, isFalse);
      expect(eta.aiFallbackReason, 'Ngoài vùng dữ liệu giao thông TP.HCM');
      expect(eta.calibratedTravelMinutes, 25);
    });

    test('rejects an implausibly fast OSRM duration', () {
      final eta = DeliveryEtaCalculator.calculate(
        distanceMeters: 9000,
        routeDurationSeconds: 8 * 60,
        pickupLat: 10.775,
        pickupLng: 106.68,
        deliveryLat: 10.825,
        deliveryLng: 106.73,
        quotedAt: DateTime(2026, 7, 29, 12),
      );

      expect(eta.usedRouteDuration, isFalse);
      expect(eta.usedAiCorrection, isTrue);
      expect(eta.rawRouteMinutes, 8);
    });
  });

  test('DeliveryFeeCalculator returns one coherent HCMC route quote', () async {
    final quote = await DeliveryFeeCalculator.estimate(
      pickupLat: 10.775,
      pickupLng: 106.68,
      deliveryLat: 10.825,
      deliveryLng: 106.73,
      serviceType: 'standard',
      osrm: _NineKilometerOsrm(),
      quotedAt: DateTime(2026, 7, 29, 17, 30),
    );

    expect(quote.source, 'osrm');
    expect(quote.distanceKm, 9);
    expect(quote.deliveryFee, 53000);
    expect(quote.eta.usedAiCorrection, isTrue);
    expect(quote.eta.aiModelVersion, 'hcm_utraffic_lgbm_v2_road_profile');
  });

  testWidgets('quote card shows a customer-friendly ETA breakdown', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fee = DeliveryPricingPolicy.calculate(distanceMeters: 9000);
    final eta = _hcmEta(quotedAt: DateTime(2026, 7, 29, 17, 30));
    final data = OrderFormData(
      pickupAddress: 'Điểm lấy hàng TP.HCM',
      pickupLat: 10.775,
      pickupLng: 106.68,
      deliveryAddress: 'Điểm giao hàng TP.HCM',
      deliveryLat: 10.825,
      deliveryLng: 106.73,
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
      durationSeconds: 20 * 60,
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
    expect(find.text(eta.rangeLabel), findsOneWidget);
    expect(find.text('Ước tính thời gian giao'), findsOneWidget);
    expect(
      find.text('Dựa trên lộ trình và khung giờ giao hàng'),
      findsOneWidget,
    );
    expect(find.textContaining('km đường bộ'), findsNothing);
    expect(find.textContaining('Tìm tài xế tối đa'), findsNothing);

    await tester.tap(find.byKey(const Key('eta-ai-details-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Thời gian theo lộ trình'), findsOneWidget);
    expect(find.text('Điều chỉnh theo khung giờ'), findsOneWidget);
    expect(
      find.text('×${eta.aiTrafficMultiplier!.toStringAsFixed(2)}'),
      findsNothing,
    );
    expect(find.text('+4 phút'), findsOneWidget);
    expect(
      find.textContaining('Thời gian có thể thay đổi theo thực tế'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

DeliveryEtaEstimate _hcmEta({required DateTime quotedAt}) {
  return DeliveryEtaCalculator.calculate(
    distanceMeters: 9000,
    routeDurationSeconds: 20 * 60,
    pickupLat: 10.775,
    pickupLng: 106.68,
    deliveryLat: 10.825,
    deliveryLng: 106.73,
    quotedAt: quotedAt,
  );
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
      durationSeconds: 20 * 60,
    );
  }
}
