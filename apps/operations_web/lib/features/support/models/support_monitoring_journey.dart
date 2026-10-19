import '../models/support_ticket.dart';
import '../../risk_reports/models/risk_journey.dart';

/// Historical bounds come from the server's incident snapshot, never the
/// current assignment. Server text uses Asia/Ho_Chi_Minh (UTC+7).
class SupportMonitoringJourney {
  SupportMonitoringJourney(this.ticket)
    : start = _timestamp(ticket.message, 'Nhận đơn'),
      end = _timestamp(ticket.message, 'Phát hiện');

  final SupportTicket ticket;
  final DateTime? start;
  final DateTime? end;
  bool get hasWindow => start != null && end != null && !end!.isBefore(start!);

  RiskJourney select(RiskJourney source) {
    if (!hasWindow) return RiskJourney([]);
    final candidates = source.points.where(
      (p) =>
          !p.time.isBefore(start!) &&
          p.time.isBefore(end!.add(const Duration(seconds: 1))),
    );
    final driverId = ticket.isDriverRequester ? ticket.requesterId : null;
    final drivers = candidates.map((p) => p.driverId).toSet();
    // Customer cases have no historical driver FK. Only accept an unambiguous
    // identified driver within the archived assignment window.
    final selectedDriver =
        driverId ??
        (drivers.length == 1 && !drivers.contains('') ? drivers.single : null);
    return RiskJourney(
      candidates.where(
        (p) => selectedDriver != null && p.driverId == selectedDriver,
      ),
      unavailableChunks: source.unavailableChunks,
    );
  }

  static DateTime? _timestamp(String body, String label) {
    final match = RegExp(
      '(?:^|\\n)$label: (\\d{2})/(\\d{2})/(\\d{4}) (\\d{2}):(\\d{2}):(\\d{2})(?:\\r?\\n|\$)',
    ).firstMatch(body);
    if (match == null) return null;
    final n = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
    final local = DateTime.utc(n[2], n[1], n[0], n[3], n[4], n[5]);
    if (local.year != n[2] ||
        local.month != n[1] ||
        local.day != n[0] ||
        local.hour != n[3] ||
        local.minute != n[4] ||
        local.second != n[5]) {
      return null;
    }
    return local.subtract(const Duration(hours: 7));
  }
}
