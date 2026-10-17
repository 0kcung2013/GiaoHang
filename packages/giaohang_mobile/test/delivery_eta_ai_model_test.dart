import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_mobile/core/ml/delivery_eta_ai_model.dart';
import 'package:giaohang_mobile/core/ml/delivery_eta_ai_calibrator.dart';

void main() {
  test('Dart speed matches Python for every minute of a full week', () {
    final cases =
        jsonDecode(
              File(
                'test/fixtures/smarttraffic_speed_parity.json',
              ).readAsStringSync(),
            )
            as List;
    for (final c in cases) {
      expect(
        DeliveryEtaAiCalibrator.predictSpeed(DateTime.parse(c['at'])),
        closeTo(c['speed'], 1e-9),
        reason: c['at'],
      );
    }
  });
  test('Dart route time matches Edge including hour/day crossings', () {
    final cases =
        jsonDecode(
              File(
                'test/fixtures/smarttraffic_route_parity.json',
              ).readAsStringSync(),
            )
            as List;
    for (final c in cases) {
      expect(
        DeliveryEtaAiCalibrator.travelMinutesForDistance(
          (c['meters'] as num) / 1000,
          DateTime.parse(c['at']),
        ),
        closeTo(c['minutes'], 1e-9),
      );
    }
  });
  test(
    'speed feature contract rejects old feature vectors and nonfinite values',
    () {
      expect(
        () => DeliveryEtaAiModel.predictSpeed([1, 2]),
        throwsArgumentError,
      );
      expect(
        () => DeliveryEtaAiModel.predictSpeed([double.nan, 0, 0]),
        throwsArgumentError,
      );
    },
  );
}
