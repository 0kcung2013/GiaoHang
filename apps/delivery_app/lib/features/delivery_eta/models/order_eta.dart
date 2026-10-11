import 'dart:math' as math;

/// A server-computed prediction; the operational deadline stays in OrderModel.
class OrderEta {
  static const fixedCalculationMode = 'assignment_once_v1';
  OrderEta({
    required this.data,
    required this.serverNow,
    required this.observedAt,
    this.issue,
  });

  final Map<String, dynamic>? data;
  final DateTime serverNow;
  final DateTime observedAt;
  final String? issue;
  String? get phase => data?['phase'] as String?;
  DateTime? get predictedAt =>
      DateTime.tryParse(data?['predicted_at']?.toString() ?? '');
  DateTime? get computedAt =>
      DateTime.tryParse(data?['computed_at']?.toString() ?? '');
  bool get hasEstimate => computedAt != null;
  bool get isFixed => data?['calculation_mode'] == fixedCalculationMode;
  bool get isSynthetic => data?['is_synthetic'] == true;
  double number(String name) => (data?[name] as num?)?.toDouble() ?? 0;
  bool get usesAi =>
      data?['approach']?['used_ai'] == true ||
      data?['delivery']?['used_ai'] == true;
  DateTime serverTimeAt(DateTime clock) =>
      serverNow.add(clock.difference(observedAt));
  bool staleAt(DateTime clock) =>
      issue != null ||
      (!isFixed &&
          computedAt != null &&
          serverTimeAt(clock).difference(computedAt!) >
              const Duration(minutes: 2));
  int remainingAt(DateTime clock) => predictedAt == null
      ? 0
      : math
            .max(0, predictedAt!.difference(serverTimeAt(clock)).inSeconds / 60)
            .ceil();

  factory OrderEta.fromJson(Map<String, dynamic> json, {DateTime? observedAt}) {
    final now = observedAt ?? DateTime.now();
    return OrderEta(
      data: json['eta'] is Map
          ? Map<String, dynamic>.from(json['eta'] as Map)
          : null,
      serverNow: DateTime.tryParse(json['server_now']?.toString() ?? '') ?? now,
      observedAt: now,
      issue: json['issue'] as String?,
    );
  }
}
