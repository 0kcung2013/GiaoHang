import 'package:latlong2/latlong.dart';

void main() {
  final p1 = LatLng(10.957533, 106.64322);
  final p2 = LatLng(37.4219999, -122.0840575);
  final distance = const Distance().as(LengthUnit.Meter, p1, p2);
  print('Distance in meters: $distance');
  print('Distance in km: ${distance / 1000}');
}
