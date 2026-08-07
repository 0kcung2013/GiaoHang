import 'package:delivery_app/core/ml/delivery_eta_ai_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dart LightGBM inference matches Python reference predictions', () {
    final cases = <(List<double>, double)>[
      (
        [
          10.785519950000001,
          106.689677,
          0.9914448613738104,
          0.1305261922200517,
          0,
          1,
          0,
          0,
          15,
          35,
          2,
          1,
        ],
        0.005077286533963487,
      ),
      (
        [
          10.79359165,
          106.65915530000001,
          0.9914448613738104,
          0.1305261922200517,
          0,
          1,
          0,
          0,
          37,
          35,
          4,
          1,
        ],
        0.005077286533963487,
      ),
      (
        [
          10.79934115,
          106.6597985,
          0.9914448613738104,
          0.1305261922200517,
          0.7818314824680298,
          0.6234898018587336,
          0,
          0,
          18,
          35,
          2,
          1.4583213889844435,
        ],
        0.14415510757544736,
      ),
    ];

    for (final (features, expected) in cases) {
      expect(
        DeliveryEtaAiModel.predictLogTrafficMultiplier(features),
        closeTo(expected, 1e-9),
      );
    }
  });

  test('rejects malformed feature vectors', () {
    expect(
      () => DeliveryEtaAiModel.predictLogTrafficMultiplier([1, 2]),
      throwsArgumentError,
    );
  });
}
