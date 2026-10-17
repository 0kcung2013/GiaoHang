import 'package:giaohang_storage/giaohang_storage.dart';
import '../models/risk_journey.dart';

class RiskJourneyRepository {
  RiskJourneyRepository({R2MediaClient? client})
    : _client = client ?? R2MediaClient.supabase();
  final R2MediaClient _client;
  Future<RiskJourney> fetch(String orderId) async {
    final points = <RiskJourneyPoint>[];
    var unavailable = 0;
    String? cursor;
    final seen = <String>{};
    do {
      final page = await _client.readGpsHistory(orderId, cursor: cursor);
      points.addAll(
        (page['points'] as List).map(
          (p) => RiskJourneyPoint.fromJson(Map<String, dynamic>.from(p as Map)),
        ),
      );
      unavailable += (page['unavailableChunks'] as num?)?.toInt() ?? 0;
      cursor = page['nextCursor'] as String?;
      if (cursor != null && !seen.add(cursor)) {
        throw StateError('Repeated GPS cursor');
      }
    } while (cursor != null);
    return RiskJourney(points, unavailableChunks: unavailable);
  }
}
