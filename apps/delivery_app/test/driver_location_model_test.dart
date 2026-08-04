import 'package:delivery_app/core/models/driver_location_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DriverLocationModel', () {
    test('fromJson creates correct model', () {
      final json = {
        'id': 'loc-1',
        'driver_id': 'driver-1',
        'lat': 10.762622,
        'lng': 106.660172,
        'heading': 90.0,
        'speed': 30.5,
        'is_active': true,
        'created_at': '2026-07-12T10:00:00Z',
      };

      final model = DriverLocationModel.fromJson(json);

      expect(model.id, 'loc-1');
      expect(model.driverId, 'driver-1');
      expect(model.lat, 10.762622);
      expect(model.lng, 106.660172);
      expect(model.heading, 90.0);
      expect(model.speed, 30.5);
      expect(model.isActive, true);
    });

    test('toJson creates correct map', () {
      final model = DriverLocationModel(
        id: 'loc-1',
        driverId: 'driver-1',
        lat: 10.762622,
        lng: 106.660172,
        heading: 90.0,
        speed: 30.5,
        isActive: true,
        createdAt: DateTime(2026, 7, 12, 10, 0, 0),
      );

      final json = model.toJson();

      expect(json['id'], 'loc-1');
      expect(json['driver_id'], 'driver-1');
      expect(json['lat'], 10.762622);
      expect(json['lng'], 106.660172);
      expect(json['heading'], 90.0);
      expect(json['speed'], 30.5);
      expect(json['is_active'], true);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'loc-1',
        'driver_id': 'driver-1',
        'lat': 10.0,
        'lng': 106.0,
        'created_at': '2026-07-12T00:00:00Z',
      };

      final model = DriverLocationModel.fromJson(json);

      expect(model.heading, null);
      expect(model.speed, null);
      expect(model.isActive, true);
    });

    test('fromJson handles int values for double fields', () {
      final json = {
        'id': 'loc-1',
        'driver_id': 'driver-1',
        'lat': 10,
        'lng': 106,
        'created_at': '2026-07-12T00:00:00Z',
      };

      final model = DriverLocationModel.fromJson(json);

      expect(model.lat, 10.0);
      expect(model.lng, 106.0);
    });

    test('fromJson handles null lat/lng as 0', () {
      final json = <String, dynamic>{
        'id': 'loc-1',
        'driver_id': 'driver-1',
        'lat': null,
        'lng': null,
        'created_at': null,
      };

      final model = DriverLocationModel.fromJson(json);

      expect(model.lat, 0);
      expect(model.lng, 0);
    });
  });
}
