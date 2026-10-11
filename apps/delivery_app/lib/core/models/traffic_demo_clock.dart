/// Fixed clocks present in the training source. Operational clocks remain real.
class TrafficDemoClock {
  TrafficDemoClock._();
  static const peak = 'peak';
  static const offPeak = 'off_peak';
  static String? validKey(String? key) =>
      key == peak || key == offPeak ? key : null;
  static DateTime? forecastAt(String? key) => switch (validKey(key)) {
    peak => DateTime.parse('2024-04-03T07:00:00+07:00'),
    offPeak => DateTime.parse('2024-04-03T14:00:00+07:00'),
    _ => null,
  };
}
