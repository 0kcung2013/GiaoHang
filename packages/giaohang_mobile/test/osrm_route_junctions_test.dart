import 'package:giaohang_mobile/core/utils/osrm_route_junctions.dart';
import 'package:giaohang_mobile/core/services/osrm_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test(
    'OSRM crossroads are extracted, deduplicated and survive attaching a forecast',
    () {
      final raw = {
        'legs': [
          {
            'steps': [
              {
                'intersections': [
                  {
                    'location': [106.6, 10.75],
                    'bearings': [0, 90, 180],
                  },
                  {
                    'location': [106.6, 10.75],
                    'bearings': [0, 90, 180],
                  },
                  {
                    'location': [106.61, 10.75],
                    'bearings': [90, 270],
                  },
                  {
                    'location': [999, 10.75],
                    'bearings': [0, 90, 180],
                  },
                ],
              },
            ],
          },
        ],
      };
      expect(extractRouteJunctions(raw), [
        [106.6, 10.75],
      ]);
      const route = OsrmRouteResult(
        points: [LatLng(10.75, 106.6), LatLng(10.75, 106.61)],
        distanceMeters: 1000,
        durationSeconds: 120,
        junctionPoints: [LatLng(10.75, 106.6)],
      );
      expect(route.withForecast({}).junctionPoints, route.junctionPoints);
    },
  );
}
