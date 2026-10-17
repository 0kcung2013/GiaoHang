import 'driver_account_strings.dart';

String driverAccountValue(String value) =>
    value.isEmpty ? DriverAccountStrings.notUpdated : value;

String driverVehicleTypeLabel(String value) {
  return switch (value.toLowerCase()) {
    'motorbike' || 'motorcycle' || 'bike' => 'Xe máy',
    'car' => 'Ô tô',
    'truck' => 'Xe tải',
    _ => driverAccountValue(value),
  };
}

String driverProfileCode(String value) {
  if (value.isEmpty) return DriverAccountStrings.notUpdated;
  final normalized = value.replaceAll('-', '').toUpperCase();
  return normalized.length <= 8 ? normalized : normalized.substring(0, 8);
}

String driverMaskedDocument(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty) return DriverAccountStrings.notUpdated;
  if (normalized.length <= 4) return List.filled(normalized.length, '•').join();
  return '${List.filled(normalized.length - 4, '•').join()}${normalized.substring(normalized.length - 4)}';
}
