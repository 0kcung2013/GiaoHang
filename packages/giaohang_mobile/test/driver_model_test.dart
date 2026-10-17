import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  group('DriverModel Phase A schema', () {
    test('fromJson parses Phase A + Phase B fields', () {
      final driver = DriverModel.fromJson({
        'id': 'd1',
        'user_id': 'u1',
        'vehicle_type': 'Xe máy',
        'license_plate': '51A-123.45',
        'vehicle_brand_model': 'Honda Wave',
        'vehicle_color': 'Đỏ',
        'is_available': true,
        'current_lat': 10.7,
        'current_lng': 106.7,
        'updated_at': '2026-07-22T00:00:00.000Z',
        'rating': 4.8,
        'total_deliveries': 12,
        'approval_status': 'approved',
        'full_name': 'Nguyen Van A',
        'email': 'a@test.com',
        'phone': '0901234567',
        'avatar_url': 'https://example.com/a.jpg',
        'verified_at': '2026-07-20T00:00:00.000Z',
        'rejection_reason': null,
        'submitted_at': '2026-07-19T00:00:00.000Z',
        'id_card_number': '001234567890',
        'vehicle_photo_url': 'https://example.com/xe.jpg',
      });

      expect(driver.vehicleBrandModel, 'Honda Wave');
      expect(driver.vehicleColor, 'Đỏ');
      expect(driver.avatarUrl, 'https://example.com/a.jpg');
      expect(driver.isVerified, isTrue);
      expect(driver.isNewDriver, isFalse);
      expect(driver.idCardNumber, '001234567890');
      expect(driver.vehiclePhotoUrl, 'https://example.com/xe.jpg');
    });

    test('isNewDriver when totalDeliveries < 5', () {
      final driver = DriverModel.fromJson({
        'id': 'd2',
        'user_id': 'u2',
        'is_available': false,
        'updated_at': '2026-07-22T00:00:00.000Z',
        'total_deliveries': 2,
        'approval_status': 'pending',
      });

      expect(driver.isNewDriver, isTrue);
      expect(driver.isVerified, isFalse);
    });

    test('admin_list_drivers shape uses driver_id', () {
      final driver = DriverModel.fromJson({
        'driver_id': 'd3',
        'user_id': 'u3',
        'vehicle_brand_model': 'Toyota Vios',
        'vehicle_color': 'Trắng',
        'is_available': true,
        'updated_at': '2026-07-22T00:00:00.000Z',
        'total_deliveries': 0,
        'approval_status': 'approved',
        'avatar_url': null,
      });

      expect(driver.id, 'd3');
      expect(driver.vehicleBrandModel, 'Toyota Vios');
    });

    test('fromPublicProfileJson + vehicleSummary', () {
      final driver = DriverModel.fromPublicProfileJson({
        'driver_id': 'd4',
        'user_id': 'u4',
        'full_name': 'Tran Van B',
        'avatar_url': null,
        'phone': '0912345678',
        'vehicle_type': 'Xe máy',
        'vehicle_brand_model': 'Honda Wave',
        'vehicle_color': 'Đỏ',
        'license_plate': '51A-999.99',
        'rating': 4.9,
        'total_deliveries': 20,
        'is_verified': true,
        'approval_status': 'approved',
        'member_since': '2026-01-01T00:00:00.000Z',
        'is_available': true,
        'current_lat': 10.7,
        'current_lng': 106.7,
      });

      expect(driver.id, 'd4');
      expect(driver.fullName, 'Tran Van B');
      expect(driver.isVerified, isTrue);
      expect(driver.vehicleSummary, 'Xe máy · Honda Wave · Đỏ');
      expect(driver.ratingLabel, '4.9');
    });
  });
}
