/// Trạng thái nghiệp vụ hiện tại, do server sở hữu; không phải lịch sử GPS.
class DriverMonitoring {
  const DriverMonitoring({
    required this.assignmentId,
    required this.driverId,
    required this.acceptedAt,
    this.lastReceivedAt,
    this.departedAt,
    this.atPickupAt,
    this.reclaimedAt,
    this.incidentAt,
    this.incidentReason,
    this.driverTicketId,
    this.customerTicketId,
  });

  final String assignmentId;
  final String driverId;
  final DateTime acceptedAt;
  final DateTime? lastReceivedAt;
  final DateTime? departedAt;
  final DateTime? atPickupAt;
  final DateTime? reclaimedAt;
  final DateTime? incidentAt;
  final String? incidentReason;
  final String? driverTicketId;
  final String? customerTicketId;

  bool get isReclaimed => reclaimedAt != null;
  bool get hasStarted => departedAt != null || atPickupAt != null;
  Duration gpsGapAt(DateTime serverNow) =>
      _positiveDifference(serverNow, lastReceivedAt ?? acceptedAt);
  Duration elapsedAt(DateTime serverNow) =>
      _positiveDifference(serverNow, acceptedAt);
  bool gpsMissingAt(DateTime serverNow) =>
      gpsGapAt(serverNow) >= const Duration(seconds: 90);

  static DriverMonitoring? fromJson(dynamic json) {
    if (json is! Map) return null;
    final acceptedAt = _date(json['accepted_at']);
    final driverId = json['driver_id']?.toString();
    final assignmentId = json['assignment_id']?.toString();
    if (acceptedAt == null || driverId == null || assignmentId == null)
      return null;
    return DriverMonitoring(
      assignmentId: assignmentId,
      driverId: driverId,
      acceptedAt: acceptedAt,
      lastReceivedAt: _date(json['last_received_at']),
      departedAt: _date(json['departed_at']),
      atPickupAt: _date(json['at_pickup_at']),
      reclaimedAt: _date(json['reclaimed_at']),
      incidentAt: _date(json['incident_at']),
      incidentReason: json['incident_reason']?.toString(),
      driverTicketId: json['driver_ticket_id']?.toString(),
      customerTicketId: json['customer_ticket_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'assignment_id': assignmentId,
    'driver_id': driverId,
    'accepted_at': acceptedAt.toUtc().toIso8601String(),
    'last_received_at': lastReceivedAt?.toUtc().toIso8601String(),
    'departed_at': departedAt?.toUtc().toIso8601String(),
    'at_pickup_at': atPickupAt?.toUtc().toIso8601String(),
    'reclaimed_at': reclaimedAt?.toUtc().toIso8601String(),
    'incident_at': incidentAt?.toUtc().toIso8601String(),
    'incident_reason': incidentReason,
    'driver_ticket_id': driverTicketId,
    'customer_ticket_id': customerTicketId,
  };

  static DateTime? _date(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '')?.toUtc();
  static Duration _positiveDifference(DateTime end, DateTime start) =>
      end.isBefore(start) ? Duration.zero : end.difference(start);
}

class DriverMonitoringSnapshot {
  DriverMonitoringSnapshot.fromJson(Map<String, dynamic> json)
    : state = DriverMonitoring.fromJson(json['state']),
      released = json['released'] == true,
      status = json['status']?.toString(),
      supportTicketId = json['support_ticket_id']?.toString(),
      serverNow = DateTime.parse(json['server_now'].toString()).toUtc();

  final DriverMonitoring? state;
  final bool released;
  final String? status;
  final String? supportTicketId;
  final DateTime serverNow;
}

abstract final class DriverMonitoringStrings {
  static const active = 'Giám sát hành trình đang bật';
  static const missing = 'Mất cập nhật vị trí';
  static const recover = 'Khôi phục GPS';
  static const preparing = 'Bạn có 5 phút chuẩn bị từ lúc nhận đơn.';
  static const reminder =
      'Đã hết thời gian chuẩn bị. Vui lòng đến điểm lấy hàng.';
  static const warning =
      'Chưa xuất phát: hệ thống thu hồi đơn ở phút thứ 10 nếu chưa nhận hàng.';
  static const gpsWarning =
      'Kiểm tra quyền vị trí và mạng. Mất GPS đủ 10 phút sẽ thu hồi đơn chưa nhận hàng.';
  static const custodyWarning =
      'Bạn đang giữ hàng. Mất GPS đủ 10 phút sẽ chuyển CSKH xác minh; hãy tiếp tục giao hàng.';
  static const waitingPickup =
      'Đã đến điểm lấy. Giám sát GPS tiếp tục hoạt động.';
  static const reclaimedTitle = 'Đơn đã chuyển sang tìm tài xế mới';
  static const reclaimedBody =
      'Hệ thống đã thu hồi phân công vì chưa xuất phát hoặc mất GPS quá 10 phút trước khi nhận hàng. Bạn có thể trao đổi với CSKH trong hồ sơ thông báo.';
  static const support = 'Trao đổi với CSKH';
  static const acknowledge = 'Đã hiểu';
  static const syncing = 'Đang kiểm tra giám sát';
  static const loadError = 'Chưa kết nối được bộ giám sát. Đang thử lại.';
  static const recoveryError =
      'Chưa lấy được GPS mới. Kiểm tra quyền vị trí và thử lại.';
  static const systemAuthor = 'Hệ thống';
}
