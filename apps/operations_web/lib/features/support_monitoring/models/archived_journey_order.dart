import 'package:giaohang_domain/giaohang_domain.dart';

class GpsArchive {
  const GpsArchive({
    required this.orderId,
    required this.firstDay,
    required this.lastDay,
    required this.chunks,
  });
  final String orderId;
  final DateTime firstDay;
  final DateTime lastDay;
  final int chunks;

  factory GpsArchive.fromJson(Map<String, dynamic> row) => GpsArchive(
    orderId: row['orderId'] as String,
    firstDay: DateTime.parse('${row['firstDay']}T00:00:00Z'),
    lastDay: DateTime.parse('${row['lastDay']}T00:00:00Z'),
    chunks: (row['chunks'] as num).toInt(),
  );

  GpsArchive merge(GpsArchive next) => GpsArchive(
    orderId: orderId,
    firstDay: firstDay.isBefore(next.firstDay) ? firstDay : next.firstDay,
    lastDay: lastDay.isAfter(next.lastDay) ? lastDay : next.lastDay,
    chunks: chunks + next.chunks,
  );
}

class ArchivedJourneyOrder {
  const ArchivedJourneyOrder({required this.archive, required this.order});
  final GpsArchive archive;
  final RiskOrderSummary order;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    return [
      order.id,
      order.trackingCode,
      order.pickupAddress,
      order.deliveryAddress,
    ].any((text) => text.toLowerCase().contains(q));
  }
}
