import 'dart:convert';
import 'package:http/http.dart' as http;

class LatLng {
  final double latitude;
  final double longitude;
  LatLng(this.latitude, this.longitude);
  @override
  String toString() => 'LatLng($latitude, $longitude)';
}

List<LatLng> decodePolyline(String encoded) {
  final points = <LatLng>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  while (index < encoded.length) {
    var shift = 0;
    var result = 0;
    int byte;

    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1F) << shift;
      shift += 5;
    } while (byte >= 0x20);

    final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += dlat;

    shift = 0;
    result = 0;

    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1F) << shift;
      shift += 5;
    } while (byte >= 0x20);

    final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += dlng;

    points.add(LatLng(lat / 1e5, lng / 1e5));
  }

  return points;
}

void main() async {
  // Correct coordinates from screenshot:
  final driver = LatLng(10.957533, 106.64322);
  final pickup = LatLng(10.950188, 106.651317);
  final delivery = LatLng(10.954593, 106.671473);

  final waypoints = [driver, pickup, delivery];
  final coords = waypoints.map((p) => '${p.longitude},${p.latitude}').join(';');

  final url = Uri.parse(
    'https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=polyline',
  );

  print('Querying OSRM URL: $url');
  final response = await http.get(url);
  print('Status code: ${response.statusCode}');
  
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final routes = data['routes'] as List?;
    if (routes != null && routes.isNotEmpty) {
      final route = routes.first;
      final geometry = route['geometry'] as String;
      if (geometry == null || geometry.isEmpty) return null;
      print('Route Geometry length: ${geometry.length}');
      print('Route Distance: ${route['distance']} meters');
      print('Route Duration: ${route['duration']} seconds');

      final points = decodePolyline(geometry);
      print('Decoded ${points.length} points.');
      for (var i = 0; i < 5 && i < points.length; i++) {
        print('  Point $i: ${points[i].latitude}, ${points[i].longitude}');
      }
      print('  Last Point: ${points.last.latitude}, ${points.last.longitude}');
    }
  } else {
    print('Error body: ${response.body}');
  }
}
