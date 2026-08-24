enum DriverProfileChangeStatus {
  draft,
  pending,
  applying,
  approved,
  rejected,
  cancelled,
  conflicted;

  String get databaseValue => name;

  static DriverProfileChangeStatus fromDatabase(Object? value) =>
      DriverProfileChangeStatus.values.firstWhere(
        (status) => status.databaseValue == value?.toString(),
      );
}

enum DriverProfileChangeField {
  fullName('full_name'),
  email('email'),
  phone('phone'),
  avatar('avatar_path'),
  vehicleType('vehicle_type'),
  vehicleBrandModel('vehicle_brand_model'),
  vehicleColor('vehicle_color'),
  licensePlate('license_plate'),
  idCardNumber('id_card_number'),
  idCardFront('id_card_front_path'),
  idCardBack('id_card_back_path'),
  driverLicenseNumber('driver_license_number'),
  driverLicense('driver_license_path'),
  vehiclePhoto('vehicle_photo_path');

  const DriverProfileChangeField(this.requestKey);

  final String requestKey;

  String get snapshotKey => switch (this) {
    DriverProfileChangeField.avatar => 'avatar_url',
    DriverProfileChangeField.idCardFront => 'id_card_front_url',
    DriverProfileChangeField.idCardBack => 'id_card_back_url',
    DriverProfileChangeField.driverLicense => 'driver_license_url',
    DriverProfileChangeField.vehiclePhoto => 'vehicle_photo_url',
    _ => requestKey,
  };

  static DriverProfileChangeField fromRequestKey(String value) =>
      DriverProfileChangeField.values.firstWhere(
        (field) => field.requestKey == value,
      );
}

class DriverProfileFieldDiff {
  const DriverProfileFieldDiff({
    required this.field,
    required this.currentValue,
    required this.requestedValue,
  });

  final DriverProfileChangeField field;
  final Object? currentValue;
  final Object? requestedValue;

  @override
  bool operator ==(Object other) =>
      other is DriverProfileFieldDiff &&
      other.field == field &&
      other.currentValue == currentValue &&
      other.requestedValue == requestedValue;

  @override
  int get hashCode => Object.hash(field, currentValue, requestedValue);
}

class DriverProfileChangeRequest {
  const DriverProfileChangeRequest({
    required this.id,
    required this.driverId,
    required this.requestedBy,
    required this.currentSnapshot,
    required this.requestedChanges,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.decidedBy,
    this.decidedAt,
    this.decisionReason,
  });

  final String id;
  final String driverId;
  final String requestedBy;
  final Map<String, Object?>? currentSnapshot;
  final Map<String, Object?>? requestedChanges;
  final String? reason;
  final DriverProfileChangeStatus status;
  final String? decidedBy;
  final DateTime? decidedAt;
  final String? decisionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => switch (status) {
    DriverProfileChangeStatus.draft ||
    DriverProfileChangeStatus.pending ||
    DriverProfileChangeStatus.applying => true,
    DriverProfileChangeStatus.approved ||
    DriverProfileChangeStatus.rejected ||
    DriverProfileChangeStatus.cancelled ||
    DriverProfileChangeStatus.conflicted => false,
  };

  bool get canDriverCancel =>
      status == DriverProfileChangeStatus.draft ||
      status == DriverProfileChangeStatus.pending;

  factory DriverProfileChangeRequest.fromJson(Map<String, dynamic> json) {
    return DriverProfileChangeRequest(
      id: json['id']?.toString() ?? '',
      driverId: json['driver_id']?.toString() ?? '',
      requestedBy: json['requested_by']?.toString() ?? '',
      currentSnapshot: _optionalMap(json['current_snapshot']),
      requestedChanges: _optionalMap(json['requested_changes']),
      reason: json['reason']?.toString(),
      status: DriverProfileChangeStatus.fromDatabase(json['status']),
      decidedBy: json['decided_by']?.toString(),
      decidedAt: _optionalDate(json['decided_at']),
      decisionReason: json['decision_reason']?.toString(),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'driver_id': driverId,
    'requested_by': requestedBy,
    'current_snapshot': currentSnapshot,
    'requested_changes': requestedChanges,
    'reason': reason,
    'status': status.databaseValue,
    'decided_by': decidedBy,
    'decided_at': decidedAt?.toUtc().toIso8601String(),
    'decision_reason': decisionReason,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

List<DriverProfileFieldDiff> buildDriverProfileDiff(
  DriverProfileChangeRequest request,
) {
  final current = request.currentSnapshot ?? const <String, Object?>{};
  final changes = request.requestedChanges ?? const <String, Object?>{};

  for (final key in changes.keys) {
    DriverProfileChangeField.fromRequestKey(key);
  }

  return DriverProfileChangeField.values
      .where((field) => changes.containsKey(field.requestKey))
      .map((field) {
        return DriverProfileFieldDiff(
          field: field,
          currentValue: current[field.snapshotKey],
          requestedValue: changes[field.requestKey],
        );
      })
      .where((diff) => diff.currentValue != diff.requestedValue)
      .toList(growable: false);
}

Map<String, Object?>? _optionalMap(Object? value) {
  if (value == null) return null;
  return Map<String, Object?>.unmodifiable(
    Map<String, Object?>.from(value as Map),
  );
}

DateTime _date(Object? value) => DateTime.parse(value.toString()).toUtc();

DateTime? _optionalDate(Object? value) => value == null ? null : _date(value);
