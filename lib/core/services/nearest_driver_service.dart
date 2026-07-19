import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_model.dart';
import '../utils/geo_utils.dart';

/// Phân công / lọc đơn theo tài xế gần điểm lấy hàng nhất.
class NearestDriverService {
  NearestDriverService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Bán kính tìm tài xế gần nhất (mét). Demo DATN: 15km.
  static const double radiusMeters = 15000;

  static const String _ordersTable = 'orders';
  static const String _driversTable = 'drivers';
  static const String _orderStatusLogsTable = 'order_status_logs';
  static const String _statusPending = 'pending';
  static const String _statusConfirmed = 'confirmed';
  static const String _statusAssigned = 'assigned';

  /// Gán đơn cho tài xế gần điểm lấy hàng nhất.
  /// Ưu tiên RPC SECURITY DEFINER; fallback client-side nếu RPC chưa deploy.
  Future<String?> assignNearestDriver({
    required String orderId,
    required double pickupLat,
    required double pickupLng,
    double radiusMeters = NearestDriverService.radiusMeters,
  }) async {
    if (orderId.trim().isEmpty) return null;
    if (pickupLat == 0 && pickupLng == 0) return null;

    try {
      final rpcResult = await _supabase.rpc(
        'assign_order_to_nearest_driver',
        params: {
          'p_order_id': orderId,
          'p_radius_meters': radiusMeters,
        },
      );
      final assigned = rpcResult?.toString();
      if (assigned != null && assigned.isNotEmpty && assigned != 'null') {
        _log('assign:rpc ok order=$orderId driver=$assigned');
        return assigned;
      }
      _log('assign:rpc empty order=$orderId');
    } catch (error) {
      _log('assign:rpc failed, fallback client: $error');
    }

    return _assignNearestDriverClient(
      orderId: orderId,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      radiusMeters: radiusMeters,
    );
  }

  /// Chỉ giữ các đơn mà [driverUserId] là tài xế gần pickup nhất
  /// trong số tài xế available + có tọa độ + chưa reject đơn đó.
  Future<List<OrderModel>> filterOrdersForNearestDriver(
    List<OrderModel> orders,
    String driverUserId,
  ) async {
    if (orders.isEmpty) return orders;

    final candidates = await loadAssignableDrivers();
    if (candidates.isEmpty) {
      _log('nearest-filter: no drivers with location; hide all pool orders');
      return const [];
    }

    final kept = <OrderModel>[];
    for (final order in orders) {
      final eligible = candidates
          .where((d) => !order.rejectedBy.contains(d.userId))
          .toList();
      if (eligible.isEmpty) continue;

      eligible.sort((a, b) {
        final da = GeoUtils.distanceMeters(
          fromLat: a.lat,
          fromLng: a.lng,
          toLat: order.pickupLat,
          toLng: order.pickupLng,
        );
        final db = GeoUtils.distanceMeters(
          fromLat: b.lat,
          fromLng: b.lng,
          toLat: order.pickupLat,
          toLng: order.pickupLng,
        );
        return da.compareTo(db);
      });

      final nearest = eligible.first;
      final dist = GeoUtils.distanceMeters(
        fromLat: nearest.lat,
        fromLng: nearest.lng,
        toLat: order.pickupLat,
        toLng: order.pickupLng,
      );

      if (dist > radiusMeters) {
        _log(
          'nearest-filter: order=${order.id} nearest too far '
          '(${dist.toStringAsFixed(0)}m > $radiusMeters)',
        );
        continue;
      }

      if (nearest.userId == driverUserId) {
        kept.add(order);
      } else {
        _log(
          'nearest-filter: order=${order.id} offered to ${nearest.userId} '
          '(${dist.toStringAsFixed(0)}m), skip $driverUserId',
        );
      }
    }

    return kept;
  }

  /// Tài xế gần pickup nhất sau khi loại [excludingUserId] (và rejected_by).
  Future<String?> findNextNearestDriverUserId({
    required OrderModel order,
    required String excludingUserId,
  }) async {
    final candidates = await loadAssignableDrivers();
    final eligible = candidates
        .where((d) => d.userId != excludingUserId)
        .where((d) => !order.rejectedBy.contains(d.userId))
        .toList();
    if (eligible.isEmpty) return null;

    eligible.sort((a, b) {
      final da = GeoUtils.distanceMeters(
        fromLat: a.lat,
        fromLng: a.lng,
        toLat: order.pickupLat,
        toLng: order.pickupLng,
      );
      final db = GeoUtils.distanceMeters(
        fromLat: b.lat,
        fromLng: b.lng,
        toLat: order.pickupLat,
        toLng: order.pickupLng,
      );
      return da.compareTo(db);
    });

    final next = eligible.first;
    final dist = GeoUtils.distanceMeters(
      fromLat: next.lat,
      fromLng: next.lng,
      toLat: order.pickupLat,
      toLng: order.pickupLng,
    );
    if (dist > radiusMeters) return null;
    return next.userId;
  }

  Future<List<AssignableDriverPoint>> loadAssignableDrivers() async {
    try {
      final response = await _supabase
          .from(_driversTable)
          .select(
            'user_id, current_lat, current_lng, is_available, approval_status',
          )
          .eq('is_available', true)
          .eq('approval_status', 'approved');

      final drivers = <AssignableDriverPoint>[];
      for (final row in response as List<dynamic>) {
        final map = Map<String, dynamic>.from(row as Map);
        final userId = map['user_id']?.toString();
        final lat = _parseDouble(map['current_lat']);
        final lng = _parseDouble(map['current_lng']);
        if (userId == null || userId.isEmpty) continue;
        if (lat == null || lng == null) continue;
        drivers.add(AssignableDriverPoint(userId: userId, lat: lat, lng: lng));
      }
      return drivers;
    } catch (error) {
      _log('load-drivers:error $error');
      return const [];
    }
  }

  Future<String?> _assignNearestDriverClient({
    required String orderId,
    required double pickupLat,
    required double pickupLng,
    required double radiusMeters,
  }) async {
    try {
      String? nearestUserId;
      try {
        final data = await _supabase.rpc(
          'find_nearest_drivers',
          params: {
            'pickup_lat': pickupLat,
            'pickup_lng': pickupLng,
            'radius_meters': radiusMeters,
            'max_results': 1,
          },
        );
        final list = data as List<dynamic>? ?? const [];
        if (list.isNotEmpty) {
          nearestUserId = (list.first as Map)['user_id']?.toString();
        }
      } catch (_) {
        final candidates = await loadAssignableDrivers();
        if (candidates.isEmpty) return null;
        candidates.sort((a, b) {
          final da = GeoUtils.distanceMeters(
            fromLat: a.lat,
            fromLng: a.lng,
            toLat: pickupLat,
            toLng: pickupLng,
          );
          final db = GeoUtils.distanceMeters(
            fromLat: b.lat,
            fromLng: b.lng,
            toLat: pickupLat,
            toLng: pickupLng,
          );
          return da.compareTo(db);
        });
        final nearest = candidates.first;
        final dist = GeoUtils.distanceMeters(
          fromLat: nearest.lat,
          fromLng: nearest.lng,
          toLat: pickupLat,
          toLng: pickupLng,
        );
        if (dist <= radiusMeters) {
          nearestUserId = nearest.userId;
        }
      }

      if (nearestUserId == null || nearestUserId.isEmpty) {
        _log('assign:client no nearest driver for $orderId');
        return null;
      }

      final updatedAt = DateTime.now().toIso8601String();
      final response = await _supabase
          .from(_ordersTable)
          .update({
            'driver_id': nearestUserId,
            'status': _statusAssigned,
            'updated_at': updatedAt,
          })
          .eq('id', orderId)
          .inFilter('status', [_statusPending, _statusConfirmed])
          .isFilter('driver_id', null)
          .select('id')
          .maybeSingle();

      if (response == null) {
        // RLS có thể chặn customer gán status=assigned — pool filter vẫn bảo vệ.
        _log(
          'assign:client update blocked/empty order=$orderId '
          'nearest=$nearestUserId (pool filter still applies)',
        );
        return null;
      }

      try {
        await _supabase.from(_orderStatusLogsTable).insert({
          'order_id': orderId,
          'status': _statusAssigned,
          'title': 'Đã phân công tài xế',
          'description':
              'Hệ thống gán đơn cho tài xế gần điểm lấy hàng nhất.',
        });
      } catch (_) {
        // Status log optional.
      }

      _log('assign:client ok order=$orderId driver=$nearestUserId');
      return nearestUserId;
    } catch (error) {
      _log('assign:client error $error');
      return null;
    }
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[NearestDriver] $message');
    }
  }
}

class AssignableDriverPoint {
  const AssignableDriverPoint({
    required this.userId,
    required this.lat,
    required this.lng,
  });

  final String userId;
  final double lat;
  final double lng;
}
