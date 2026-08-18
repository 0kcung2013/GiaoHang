import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../location/location_ingest_config.dart';
import '../models/order_model.dart';

typedef AssignableDriverLoader =
    Future<List<AssignableDriverPoint>> Function({
      required double nearLat,
      required double nearLng,
    });

/// Tìm tài xế có thể nhận đơn từ nguồn server-authoritative.
///
/// PostgreSQL/Redis chịu trách nhiệm loại tài xế offline, chưa duyệt, đang bận
/// hoặc có vị trí quá cũ. Flutter chỉ áp dụng `rejected_by` theo từng đơn.
class NearestDriverService {
  NearestDriverService({
    SupabaseClient? client,
    AssignableDriverLoader? assignableDriverLoader,
    DateTime Function()? now,
  }) : _supabase = client ?? Supabase.instance.client,
       _assignableDriverLoader = assignableDriverLoader,
       _now = now ?? DateTime.now;

  final SupabaseClient _supabase;
  final AssignableDriverLoader? _assignableDriverLoader;
  final DateTime Function() _now;

  static const double radiusMeters = 3000;
  static const Duration locationFreshness = Duration(minutes: 3);
  static const int _maxCandidates = 50;

  Future<String?> assignNearestDriver({
    required String orderId,
    required double pickupLat,
    required double pickupLng,
    double radiusMeters = NearestDriverService.radiusMeters,
  }) async {
    if (orderId.trim().isEmpty || (pickupLat == 0 && pickupLng == 0)) {
      return null;
    }

    try {
      final rpcResult = await _supabase.rpc(
        'assign_order_to_nearest_driver',
        params: {'p_order_id': orderId, 'p_radius_meters': radiusMeters},
      );
      final assigned = rpcResult?.toString();
      if (assigned != null && assigned.isNotEmpty && assigned != 'null') {
        _log('assign:rpc ok order=$orderId driver=$assigned');
        return assigned;
      }
      return null;
    } catch (error) {
      _log('assign:rpc failed without client mutation: $error');
      throw DriverAssignmentException(
        'Không thể phân công tài xế lúc này. Vui lòng thử lại.',
        error,
      );
    }
  }

  /// Chỉ giữ đơn mà tài xế hiện tại là ứng viên hợp lệ gần nhất.
  Future<List<OrderModel>> filterOrdersForNearestDriver(
    List<OrderModel> orders,
    String driverUserId,
  ) async {
    if (orders.isEmpty || driverUserId.isEmpty) return const [];

    final allocations = await allocateOrderOffers(orders);
    return orders
        .where((order) => allocations[order.id] == driverUserId)
        .toList();
  }

  /// Phân phối lời mời theo nguyên tắc một tài xế chỉ giữ một đơn đang chờ.
  ///
  /// Đơn cũ được ưu tiên trước để kết quả ổn định giữa các thiết bị, kể cả khi
  /// stream trả danh sách mới nhất trước.
  Future<Map<String, String>> allocateOrderOffers(
    List<OrderModel> orders,
  ) async {
    if (orders.isEmpty) return const {};

    final ordered = [...orders]
      ..sort((left, right) {
        final byCreatedAt = left.createdAt.compareTo(right.createdAt);
        return byCreatedAt != 0 ? byCreatedAt : left.id.compareTo(right.id);
      });
    final reservedDriverIds = <String>{};
    final allocations = <String, String>{};

    for (final order in ordered) {
      if (order.pickupLat == 0 && order.pickupLng == 0) continue;
      final candidates = await loadAssignableDrivers(
        nearLat: order.pickupLat,
        nearLng: order.pickupLng,
      );
      final eligible = candidates.where(
        (driver) =>
            !order.rejectedBy.contains(driver.userId) &&
            !reservedDriverIds.contains(driver.userId),
      );
      final ranked = _rankCandidates(eligible);
      if (ranked.isEmpty) continue;

      final selected = ranked.first;
      reservedDriverIds.add(selected.userId);
      allocations[order.id] = selected.userId;
      _log('offer: order=${order.id} driver=${selected.userId}');
    }

    return allocations;
  }

  Future<String?> findNextNearestDriverUserId({
    required OrderModel order,
    required String excludingUserId,
  }) async {
    final candidates = await loadAssignableDrivers(
      nearLat: order.pickupLat,
      nearLng: order.pickupLng,
    );
    for (final candidate in _rankCandidates(candidates)) {
      if (candidate.userId == excludingUserId) continue;
      if (order.rejectedBy.contains(candidate.userId)) continue;
      return candidate.userId;
    }
    return null;
  }

  /// Redis là hot path; RPC Postgres là source-of-truth fallback.
  Future<List<AssignableDriverPoint>> loadAssignableDrivers({
    double? nearLat,
    double? nearLng,
  }) async {
    if (nearLat == null || nearLng == null) return const [];

    final injectedLoader = _assignableDriverLoader;
    if (injectedLoader != null) {
      return injectedLoader(nearLat: nearLat, nearLng: nearLng);
    }

    final fromRedis = await _loadAssignableDriversFromRedis(
      aroundLat: nearLat,
      aroundLng: nearLng,
    );
    if (fromRedis != null) return fromRedis;

    final fromRpc = await _loadAssignableDriversFromRpc(
      aroundLat: nearLat,
      aroundLng: nearLng,
    );
    return fromRpc ?? const [];
  }

  Future<List<AssignableDriverPoint>?> _loadAssignableDriversFromRpc({
    required double aroundLat,
    required double aroundLng,
  }) async {
    try {
      final response = await _supabase.rpc(
        'find_nearest_drivers',
        params: {
          'pickup_lat': aroundLat,
          'pickup_lng': aroundLng,
          'radius_meters': radiusMeters,
          'max_results': _maxCandidates,
        },
      );
      final rows = response as List<dynamic>? ?? const [];
      return rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .map(_candidateFromMap)
          .whereType<AssignableDriverPoint>()
          .toList();
    } catch (error) {
      _log('load-drivers:rpc failed $error');
      return null;
    }
  }

  /// null = Edge/Redis không dùng được; [] = dùng được nhưng không có ứng viên.
  Future<List<AssignableDriverPoint>?> _loadAssignableDriversFromRedis({
    required double aroundLat,
    required double aroundLng,
  }) async {
    if (!LocationIngestConfig.useEdgeIngest) return null;
    try {
      final response = await _supabase.functions.invoke(
        LocationIngestConfig.nearestFunctionName,
        body: {
          'pickup_lat': aroundLat,
          'pickup_lng': aroundLng,
          'radius_meters': radiusMeters,
          'max_results': _maxCandidates,
        },
      );
      if (response.status < 200 || response.status >= 300) return null;

      final data = response.data;
      final rawDrivers = data is Map && data['drivers'] is List
          ? data['drivers'] as List
          : (data is List ? data : null);
      if (rawDrivers == null) return null;

      final drivers = rawDrivers
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .map(_candidateFromMap)
          .whereType<AssignableDriverPoint>()
          .toList();
      _log('load-drivers:redis count=${drivers.length}');
      return drivers;
    } catch (error) {
      _log('load-drivers:redis skip $error');
      return null;
    }
  }

  AssignableDriverPoint? _candidateFromMap(Map<String, dynamic> map) {
    final userId = map['user_id']?.toString();
    final lat = _parseDouble(map['lat'] ?? map['current_lat']);
    final lng = _parseDouble(map['lng'] ?? map['current_lng']);
    if (userId == null || userId.isEmpty || lat == null || lng == null) {
      return null;
    }
    return AssignableDriverPoint(
      userId: userId,
      lat: lat,
      lng: lng,
      distanceMeters: _parseDouble(map['distance_meters']),
      rating: _parseDouble(map['rating']) ?? 0,
      locationUpdatedAt: _parseDateTime(
        map['location_updated_at'] ?? map['updated_at'],
      ),
    );
  }

  List<AssignableDriverPoint> _rankCandidates(
    Iterable<AssignableDriverPoint> candidates,
  ) {
    final freshnessCutoff = _now().toUtc().subtract(locationFreshness);
    final withDistance = candidates
        .where(
          (candidate) =>
              candidate.locationUpdatedAt != null &&
              !candidate.locationUpdatedAt!.isBefore(freshnessCutoff) &&
              candidate.distanceMeters != null &&
              candidate.distanceMeters!.isFinite &&
              candidate.distanceMeters! >= 0,
        )
        .toList();
    if (withDistance.isEmpty) return const [];

    withDistance.sort((left, right) {
      final byDistance = left.distanceMeters!.compareTo(right.distanceMeters!);
      if (byDistance != 0) return byDistance;
      return left.userId.compareTo(right.userId);
    });
    return withDistance;
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) return value.toUtc();
    return DateTime.tryParse(value?.toString() ?? '')?.toUtc();
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[NearestDriver] $message');
  }
}

class DriverAssignmentException implements Exception {
  const DriverAssignmentException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class AssignableDriverPoint {
  const AssignableDriverPoint({
    required this.userId,
    required this.lat,
    required this.lng,
    this.distanceMeters,
    this.rating = 0,
    this.locationUpdatedAt,
  });

  final String userId;
  final double lat;
  final double lng;
  final double? distanceMeters;
  final double rating;
  final DateTime? locationUpdatedAt;
}
