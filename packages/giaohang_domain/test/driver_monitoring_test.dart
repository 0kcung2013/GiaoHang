import 'package:test/test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  final accepted = DateTime.utc(2026, 10, 11, 10);
  Map<String, dynamic> state() => {
    'assignment_id': 'assignment',
    'driver_id': 'driver',
    'accepted_at': accepted.toIso8601String(),
  };
  test('GPS gap starts at acceptance until a valid sample arrives', () {
    final monitor = DriverMonitoring.fromJson(state())!;
    expect(
      monitor.gpsGapAt(accepted.add(const Duration(minutes: 10))),
      const Duration(minutes: 10),
    );
    expect(
      monitor.elapsedAt(accepted.subtract(const Duration(minutes: 1))),
      Duration.zero,
    );
  });
  test('departure and waiting at pickup both finish initial start rule', () {
    expect(DriverMonitoring.fromJson(state())!.hasStarted, isFalse);
    for (final key in ['departed_at', 'at_pickup_at']) {
      expect(
        DriverMonitoring.fromJson({
          ...state(),
          key: accepted.toIso8601String(),
        })!.hasStarted,
        isTrue,
      );
    }
  });
  test('recovered GPS uses newest receipt rather than acceptance', () {
    final now = accepted.add(const Duration(minutes: 9));
    final monitor = DriverMonitoring.fromJson({
      ...state(),
      'last_received_at': now.toIso8601String(),
    })!;
    expect(monitor.gpsGapAt(now), Duration.zero);
    expect(monitor.gpsMissingAt(now.add(const Duration(seconds: 90))), isTrue);
  });
  test(
    'old released driver snapshot has a private case and no new driver state',
    () {
      final snapshot = DriverMonitoringSnapshot.fromJson({
        'released': true,
        'support_ticket_id': 'case',
        'server_now': accepted.toIso8601String(),
      });
      expect(snapshot.released, isTrue);
      expect(snapshot.state, isNull);
      expect(snapshot.supportTicketId, 'case');
    },
  );
  test('legacy and malformed monitoring is absent', () {
    expect(DriverMonitoring.fromJson(null), isNull);
    expect(DriverMonitoring.fromJson({'accepted_at': 'bad'}), isNull);
  });
  test(
    'monitoring incident dates and case references survive snapshot roundtrip',
    () {
      final monitor = DriverMonitoring.fromJson({
        ...state(),
        'reclaimed_at': accepted.toIso8601String(),
        'incident_reason': 'gps_lost',
        'driver_ticket_id': 'driver-case',
        'customer_ticket_id': 'customer-case',
      })!;
      final parsed = DriverMonitoring.fromJson(monitor.toJson())!;
      expect(parsed.isReclaimed, isTrue);
      expect(parsed.incidentReason, 'gps_lost');
      expect(parsed.customerTicketId, 'customer-case');
      expect(parsed.driverTicketId, 'driver-case');
    },
  );
  test(
    'automatic support case requires staff reply and retains requester contact',
    () {
      final ticket = SupportTicket.fromJson({
        'id': 'case',
        'requester_id': 'old-driver',
        'status': 'open',
        'requester_role': 'driver',
        'requester_name': 'Tài xế cũ',
        'requester_phone': '0901234567',
        'requester_email': 'driver@example.invalid',
        'last_message_role': 'system',
      });
      expect(ticket.needsReply, isTrue);
      expect(ticket.isDriverRequester, isTrue);
      expect(
        SupportTicket.fromJson(ticket.toJson()).requesterPhone,
        '0901234567',
      );
    },
  );
}
