class DriverDeliveryArrival {
  const DriverDeliveryArrival({
    required this.arrivedAt,
    required this.serverNow,
    required this.canReport,
  });
  final DateTime? arrivedAt;
  final DateTime serverNow;
  final bool canReport;
  static const minimumWait = Duration(minutes: 10);
  Duration? get elapsed =>
      arrivedAt == null ? null : serverNow.difference(arrivedAt!);
  factory DriverDeliveryArrival.fromJson(Map<String, dynamic> json) =>
      DriverDeliveryArrival(
        arrivedAt: json['delivery_arrived_at'] == null
            ? null
            : DateTime.parse(json['delivery_arrived_at'] as String),
        serverNow: DateTime.parse(json['server_now'] as String),
        canReport: json['can_report_recipient'] == true,
      );
}
