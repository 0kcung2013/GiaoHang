import 'package:giaohang_domain/giaohang_domain.dart';

import 'driver_account_view_data.dart';

class DriverProfileChangeFormState {
  const DriverProfileChangeFormState({
    this.selectedFields = const {},
    this.changes = const {},
    this.reason = '',
  });

  final Set<DriverProfileChangeField> selectedFields;
  final Map<DriverProfileChangeField, Object?> changes;
  final String reason;

  DriverProfileChangeFormState toggle(DriverProfileChangeField field) {
    final selected = {...selectedFields};
    final nextChanges = {...changes};
    if (!selected.add(field)) {
      selected.remove(field);
      nextChanges.remove(field);
    }
    return copyWith(selectedFields: selected, changes: nextChanges);
  }

  DriverProfileChangeFormState setValue(
    DriverProfileChangeField field,
    Object? value,
  ) {
    return copyWith(
      selectedFields: {...selectedFields, field},
      changes: {...changes, field: value},
    );
  }

  DriverProfileChangeFormState setReason(String value) =>
      copyWith(reason: value);

  Map<DriverProfileChangeField, Object?> normalizedChanges(
    DriverAccountViewData profile,
  ) {
    final result = <DriverProfileChangeField, Object?>{};
    for (final field in selectedFields) {
      final raw = changes[field];
      final normalized = raw is String ? raw.trim() : raw;
      if (normalized == null || normalized == '') continue;
      final current = currentDriverProfileValue(profile, field);
      if (normalized == current) continue;
      result[field] = normalized;
    }
    return result;
  }

  DriverProfileChangeFormState copyWith({
    Set<DriverProfileChangeField>? selectedFields,
    Map<DriverProfileChangeField, Object?>? changes,
    String? reason,
  }) {
    return DriverProfileChangeFormState(
      selectedFields: selectedFields ?? this.selectedFields,
      changes: changes ?? this.changes,
      reason: reason ?? this.reason,
    );
  }

  factory DriverProfileChangeFormState.fromRequest(
    DriverProfileChangeRequest request,
  ) {
    final changes = <DriverProfileChangeField, Object?>{};
    for (final entry
        in (request.requestedChanges ?? const <String, Object?>{}).entries) {
      changes[DriverProfileChangeField.fromRequestKey(entry.key)] = entry.value;
    }
    return DriverProfileChangeFormState(
      selectedFields: changes.keys.toSet(),
      changes: changes,
      reason: request.reason ?? '',
    );
  }
}

Object? currentDriverProfileValue(
  DriverAccountViewData profile,
  DriverProfileChangeField field,
) {
  return switch (field) {
    DriverProfileChangeField.fullName => profile.name,
    DriverProfileChangeField.email => profile.email,
    DriverProfileChangeField.phone => profile.phone,
    DriverProfileChangeField.avatar => profile.avatarUrl,
    DriverProfileChangeField.vehicleType => profile.vehicleType,
    DriverProfileChangeField.vehicleBrandModel => profile.vehicleBrandModel,
    DriverProfileChangeField.vehicleColor => profile.vehicleColor,
    DriverProfileChangeField.licensePlate => profile.licensePlate,
    DriverProfileChangeField.idCardNumber => profile.idCardNumber,
    DriverProfileChangeField.idCardFront => profile.idCardFrontUrl,
    DriverProfileChangeField.idCardBack => profile.idCardBackUrl,
    DriverProfileChangeField.driverLicenseNumber => profile.driverLicenseNumber,
    DriverProfileChangeField.driverLicense => profile.driverLicenseUrl,
    DriverProfileChangeField.vehiclePhoto => profile.vehiclePhotoUrl,
  };
}
