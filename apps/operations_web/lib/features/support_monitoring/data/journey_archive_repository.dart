import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:giaohang_storage/giaohang_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../risk_reports/data/risk_journey_repository.dart';
import '../../risk_reports/models/risk_journey.dart';
import '../../support_orders/data/support_order_repository.dart';
import '../../support_orders/models/support_order.dart';
import '../models/archived_journey_order.dart';

abstract interface class JourneyArchiveRepository {
  Future<List<ArchivedJourneyOrder>> fetchArchives();
  Future<RiskJourney> fetchJourney(String orderId);
  Future<List<SupportOrderStatusLog>> fetchEvents(String orderId);
}

class R2JourneyArchiveRepository implements JourneyArchiveRepository {
  R2JourneyArchiveRepository({required this.client, required this.storage});
  final SupabaseClient client;
  final R2MediaClient storage;

  @override
  Future<List<ArchivedJourneyOrder>> fetchArchives() async {
    final archives = <String, GpsArchive>{};
    final seen = <String>{};
    String? cursor;
    do {
      final page = await storage.listGpsArchives(cursor: cursor);
      for (final row in page['archives'] as List) {
        final entry = GpsArchive.fromJson(
          Map<String, dynamic>.from(row as Map),
        );
        archives[entry.orderId] =
            archives[entry.orderId]?.merge(entry) ?? entry;
      }
      cursor = page['nextCursor'] as String?;
      if (cursor != null && !seen.add(cursor)) {
        throw StateError('Repeated archive cursor');
      }
    } while (cursor != null);
    final ids = archives.keys.toList();
    final result = <ArchivedJourneyOrder>[];
    for (var offset = 0; offset < ids.length; offset += 50) {
      final rows = await client
          .from('orders')
          .select(
            'id,tracking_code,status,pickup_address,pickup_lat,pickup_lng,'
            'delivery_address,delivery_lat,delivery_lng,created_at,updated_at',
          )
          .inFilter('id', ids.skip(offset).take(50).toList());
      for (final row in rows) {
        final order = RiskOrderSummary.fromJson(row);
        result.add(
          ArchivedJourneyOrder(archive: archives[order.id]!, order: order),
        );
      }
    }
    result.sort((a, b) => b.archive.lastDay.compareTo(a.archive.lastDay));
    return result;
  }

  @override
  Future<RiskJourney> fetchJourney(String orderId) =>
      RiskJourneyRepository(client: storage).fetch(orderId);

  @override
  Future<List<SupportOrderStatusLog>> fetchEvents(String orderId) =>
      SupabaseSupportOrderRepository(client).fetchStatusLogs(orderId);
}
