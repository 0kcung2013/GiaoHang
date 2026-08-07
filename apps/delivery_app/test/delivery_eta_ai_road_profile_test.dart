import 'package:delivery_app/core/ml/delivery_eta_ai_road_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns finite historical road features inside TP.HCM coverage', () {
    final features = DeliveryEtaAiRoadProfile.featuresNear(
      latitude: 10.78,
      longitude: 106.68,
    );

    expect(features, isNotNull);
    expect(features!.lengthMeters, greaterThan(0));
    expect(features.speedLimitKmh, greaterThan(0));
    expect(features.level, greaterThan(0));
    expect(features.historicalSpeedRatio, inInclusiveRange(1, 2.5));
  });
}
