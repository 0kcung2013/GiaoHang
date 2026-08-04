import 'package:latlong2/latlong.dart';

class MapPickerResult {
  const MapPickerResult({
    required this.position,
    required this.formattedAddress,
    required this.addressDetail,
    required this.deliveryNote,
  });

  final LatLng position;
  final String formattedAddress;
  final String addressDetail;
  final String deliveryNote;

  String get address {
    final detail = addressDetail.trim();
    if (detail.isEmpty) return formattedAddress.trim();
    if (formattedAddress.toLowerCase().startsWith(detail.toLowerCase())) {
      return formattedAddress.trim();
    }
    return '$detail, ${formattedAddress.trim()}';
  }
}
