import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:operations_web/features/risk_reports/models/risk_report.dart';
import 'package:operations_web/features/risk_reports/models/risk_journey.dart';
import 'package:operations_web/features/risk_reports/widgets/risk_journey_map.dart';

class _Tiles extends TileProvider {
  @override
  ImageProvider getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) => MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a7XcAAAAASUVORK5CYII=',
    ),
  );
}

void main() {
  for (final size in [const Size(375, 600), const Size(1280, 800)]) {
    testWidgets('GPS map preserves gaps and selects report time at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final time = DateTime.utc(2026, 10, 16, 8);
      final report = RiskReport.fromJson({
        'id': 'report',
        'order_id': 'order',
        'reported_by': 'driver',
        'created_at': time.add(const Duration(seconds: 5)).toIso8601String(),
        'updated_at': time.toIso8601String(),
        'orders': {
          'id': 'order',
          'pickup_lat': 10.77,
          'pickup_lng': 106.7,
          'delivery_lat': 10.78,
          'delivery_lng': 106.71,
        },
      });
      final journey = RiskJourney([
        RiskJourneyPoint(const LatLng(10.77, 106.7), time, 'driver'),
        RiskJourneyPoint(
          const LatLng(10.7701, 106.7001),
          time.add(const Duration(seconds: 5)),
          'driver',
        ),
        RiskJourneyPoint(
          const LatLng(10.78, 106.71),
          time.add(const Duration(minutes: 3)),
          'driver',
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: RiskJourneyMap(
                report: report,
                journey: journey,
                tileProvider: _Tiles(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<PolylineLayer>(find.byType(PolylineLayer)).polylines,
        hasLength(1),
      );
      expect(tester.widget<Slider>(find.byType(Slider)).value, 1);
      tester.widget<Slider>(find.byType(Slider)).onChanged!(2);
      await tester.pumpAndSettle();
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.last.point,
        journey.points.last.position,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
