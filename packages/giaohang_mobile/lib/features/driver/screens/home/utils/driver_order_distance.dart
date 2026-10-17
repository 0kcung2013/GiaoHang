String totalOrderDistanceText(double? distanceMeters) {
  if (distanceMeters == null ||
      !distanceMeters.isFinite ||
      distanceMeters < 0) {
    return 'Chưa có tổng quãng đường';
  }
  if (distanceMeters < 1000) {
    final roundedMeters = (distanceMeters / 50).round() * 50;
    return 'Tổng 2 chặng · ~${roundedMeters.clamp(0, 950)} m';
  }
  final distanceKm = distanceMeters / 1000;
  return 'Tổng 2 chặng · ~${distanceKm.toStringAsFixed(1)} km';
}

String distanceKilometersText(double? distanceMeters) {
  if (distanceMeters == null ||
      !distanceMeters.isFinite ||
      distanceMeters < 0) {
    return '—';
  }
  if (distanceMeters < 1000) {
    return '${distanceMeters.round()} m';
  }
  final distanceKm = distanceMeters / 1000;
  return '${distanceKm.toStringAsFixed(1)} km';
}
