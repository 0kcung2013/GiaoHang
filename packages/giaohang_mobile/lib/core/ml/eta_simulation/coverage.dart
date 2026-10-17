/// Sampling bounds of the training road graph (experiments/eta_simulation/features.py).
/// Expanded OSM road attributes do not expand the model's validated demo area.
class EtaSimulationCoverage {
  EtaSimulationCoverage._();

  static const version = 'hcm_training_bounds_v1';
  static const outsideReason = 'outside_training_area';
  static const minLatitude = 10.65;
  static const maxLatitude = 10.95;
  static const minLongitude = 106.50;
  static const maxLongitude = 106.90;

  /// Check the entire route, including detours between its endpoints.
  static bool containsRoute(Iterable<List<double>> coordinates) =>
      coordinates.length >= 2 &&
      coordinates.every(
        (p) =>
            p.length == 2 &&
            p[0].isFinite &&
            p[1].isFinite &&
            p[0] >= minLongitude &&
            p[0] <= maxLongitude &&
            p[1] >= minLatitude &&
            p[1] <= maxLatitude,
      );
}
