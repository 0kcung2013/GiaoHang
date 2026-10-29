import 'package:giaohang_mobile/core/services/osrm_service.dart';
import 'package:giaohang_mobile/core/models/delivery_eta_route_profile.dart';
import 'package:giaohang_mobile/core/models/order_finance.dart';
import 'package:giaohang_mobile/core/utils/delivery_eta_calculator.dart';
import 'package:giaohang_mobile/core/utils/delivery_fee_calculator.dart';
import 'package:giaohang_mobile/core/utils/delivery_pricing_policy.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/utils/order_form_data.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/utils/delivery_eta_strings.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/delivery_quote_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart' show BusinessSettings;

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

    test(
      'one distance rate applies to all kilometers after the included distance',
      () {
        final quote = DeliveryPricingPolicy.calculate(distanceMeters: 12000);

        expect(quote.standardBillableKm, 10);
        expect(quote.longBillableKm, 0);
        expect(quote.standardDistanceFee, 50000);
        expect(quote.longDistanceFee, 0);
        expect(quote.total, 68000);
      },
    );

    test('historical settings retain the original tiered price', () {
      final legacy = BusinessSettings.fromJson({
        'revision': 0,
        'values': BusinessSettings.legacyDefaults,
      });
      expect(
        DeliveryPricingPolicy.calculate(
          distanceMeters: 12000,
          settings: legacy,
        ).total,
        66000,
      );
      expect(
        DeliveryPricingPolicy.calculate(
          distanceMeters: 20000,
          settings: legacy,
        ).total,
        98000,
      );
      expect(
        DeliveryPricingPolicy.calculate(distanceMeters: 20000).total,
        108000,
      );
      expect(legacy.asSingleRate().usesLegacyPricing, isFalse);
    });

    test('rounds the final quote up to one thousand dong', () {
      final quote = DeliveryPricingPolicy.calculate(distanceMeters: 2150);

      expect(quote.total, 19000);
    });
  });

  group('DeliveryEtaCalculator', () {
    test('uses the supplied shared speed profile for ETA', () {
      final eta = _hcmEta(quotedAt: DateTime(2026, 7, 29, 17, 30));

      expect(eta.usedRouteDuration, isFalse);
      expect(eta.usedAiCorrection, isTrue);
      expect(eta.aiModelVersion, 'hcm_utraffic_segment_speed_v1');
      expect(eta.aiDatasetLabel, 'UTraffic TP.HCM');
      expect(eta.aiUsesRealtimeTraffic, isFalse);
      expect(eta.aiTrafficMultiplier, greaterThan(0));
      expect(eta.calibratedTravelMinutes, lessThan(eta.baselineTravelMinutes));
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

      expect(eta.usedRouteDuration, isFalse);
      expect(eta.usedAiCorrection, isFalse);
      expect(eta.aiFallbackReason, 'Chưa có dự báo vận tốc cho tuyến này');
      expect(eta.calibratedTravelMinutes, closeTo(21.6, 1e-9));
      expect(eta.minMinutes, 27);
      expect(eta.maxMinutes, 27);
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
      expect(eta.usedAiCorrection, isFalse);
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
    expect(quote.eta.usedAiCorrection, isFalse);
    expect(quote.eta.aiModelVersion, isNull);
  });

  for (final config in [
    (const Size(390, 760), 1.0),
    (const Size(320, 600), 1.6),
  ]) {
    for (final usesTraffic in [true, false]) {
      testWidgets(
        'quote waits for assignment at ${config.$1}, traffic=$usesTraffic',
        (tester) async {
          await tester.binding.setSurfaceSize(config.$1);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final fee = DeliveryPricingPolicy.calculate(distanceMeters: 9000);
          final eta = usesTraffic
              ? _hcmEta(quotedAt: DateTime(2026, 7, 29, 17, 30))
              : DeliveryEtaCalculator.calculate(
                  distanceMeters: 9000,
                  routeDurationSeconds: 20 * 60,
                  pickupLat: 11.05,
                  pickupLng: 106.66,
                  deliveryLat: 11.10,
                  deliveryLng: 106.70,
                  quotedAt: DateTime(2026, 7, 29, 17, 30),
                );
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
            deliveryFeePayer: DeliveryFeePayer.recipient,
            goodsValue: 0,
            codCollectionAmount: 0,
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
              home: MediaQuery(
                data: MediaQueryData(
                  size: config.$1,
                  textScaler: TextScaler.linear(config.$2),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: DeliveryQuoteCard(data: data),
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(find.text('Dự kiến giao'), findsOneWidget);
          expect(find.text(eta.rangeLabel), findsNothing);
          expect(
            find.text(DeliveryEtaStrings.waitingForDriver),
            findsOneWidget,
          );
          expect(find.text(DeliveryEtaStrings.afterAssignment), findsOneWidget);
          expect(find.textContaining('km đường bộ'), findsNothing);
          expect(find.textContaining('Tìm tài xế tối đa'), findsNothing);

          expect(find.byKey(const Key('eta-ai-details-toggle')), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
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
    speedProfile: DeliveryEtaRouteProfile.fromJson({
      'distance_meters': 9000.0,
      'forecast_at': quotedAt.toUtc().toIso8601String(),
      'route_points': [
        [106.68, 10.775],
        [106.73, 10.825],
      ],
      'used_ai': true,
      'speed_profile': [
        {
          'start_meters': 0.0,
          'end_meters': 9000.0,
          'speed_kmh': 40.0,
          'used_ai': true,
        },
      ],
    }),
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
