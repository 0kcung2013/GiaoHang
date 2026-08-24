import 'dart:convert';
import 'dart:math' as math;

import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ReturnRouteQuote {
  const ReturnRouteQuote({
    required this.originLat,
    required this.originLng,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.source,
    required this.suggestedFee,
  });

  final double originLat;
  final double originLng;
  final int distanceMeters;
  final int durationSeconds;
  final ReturnQuoteSource source;
  final int suggestedFee;
}

typedef ReturnIncidentOriginLoader =
    Future<(double, double)?> Function(String riskReportId);
typedef ReturnCurrentDriverOriginLoader =
    Future<(double, double)?> Function(String riskReportId);

class ReturnRouteQuoteService {
  ReturnRouteQuoteService(
    this._client, {
    http.Client? httpClient,
    ReturnIncidentOriginLoader? incidentOriginLoader,
    ReturnCurrentDriverOriginLoader? currentDriverOriginLoader,
  }) : _http = httpClient ?? http.Client(),
       _incidentOriginLoader = incidentOriginLoader,
       _currentDriverOriginLoader = currentDriverOriginLoader;

  final SupabaseClient _client;
  final http.Client _http;
  final ReturnIncidentOriginLoader? _incidentOriginLoader;
  final ReturnCurrentDriverOriginLoader? _currentDriverOriginLoader;

  Future<ReturnRouteQuote> quote({
    required String riskReportId,
    required RiskOrderSummary order,
    required double destinationLat,
    required double destinationLng,
  }) async {
    (double, double)? incidentOrigin;
    try {
      incidentOrigin = await (_incidentOriginLoader ?? _loadIncidentOrigin)(
        riskReportId,
      );
    } catch (_) {
      // Báo cáo cũ có thể chưa lưu vị trí; dùng GPS hồ sơ làm fallback.
    }

    (double, double)? currentDriverOrigin;
    if (incidentOrigin == null) {
      try {
        currentDriverOrigin =
            await (_currentDriverOriginLoader ?? _loadCurrentDriverOrigin)(
              riskReportId,
            );
      } catch (_) {
        // Điểm giao vẫn giữ CSKH hoạt động khi GPS hồ sơ lỗi.
      }
    }
    final origin =
        incidentOrigin ?? currentDriverOrigin ?? _deliveryOrigin(order);
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${origin.$2},${origin.$1};$destinationLng,$destinationLat'
      '?overview=false',
    );
    try {
      final response = await _http.get(uri);
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = payload['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes.first as Map<String, dynamic>;
          return _result(
            origin: origin,
            distance: (route['distance'] as num).round(),
            duration: (route['duration'] as num).round(),
            source: ReturnQuoteSource.osrm,
          );
        }
      }
    } catch (_) {
      // Fallback below keeps CSKH operational when the public router is down.
    }
    final straightMeters = _haversine(
      origin.$1,
      origin.$2,
      destinationLat,
      destinationLng,
    );
    final roadEstimate = (straightMeters * 1.28).round();
    return _result(
      origin: origin,
      distance: roadEstimate,
      duration: (roadEstimate / 7.5).round(),
      source: ReturnQuoteSource.fallback,
    );
  }

  Future<(double, double)?> _loadCurrentDriverOrigin(
    String riskReportId,
  ) async {
    final response = await _client.rpc(
      'get_support_return_driver_origin',
      params: {'p_risk_report_id': riskReportId},
    );
    if (response is! Map) return null;
    final row = Map<String, dynamic>.from(response);
    final lat = (row['current_lat'] as num?)?.toDouble();
    final lng = (row['current_lng'] as num?)?.toDouble();
    if (!_validCoordinates(lat, lng)) return null;
    return (lat!, lng!);
  }

  Future<(double, double)?> _loadIncidentOrigin(String riskReportId) async {
    final row = await _client
        .from('risk_report_attachments')
        .select('latitude,longitude')
        .eq('risk_report_id', riskReportId)
        .eq('evidence_type', 'location')
        .order('captured_at', ascending: false)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    final lat = (row?['latitude'] as num?)?.toDouble();
    final lng = (row?['longitude'] as num?)?.toDouble();
    if (!_validCoordinates(lat, lng)) return null;
    return (lat!, lng!);
  }

  (double, double) _deliveryOrigin(RiskOrderSummary order) {
    final lat = order.deliveryLat;
    final lng = order.deliveryLng;
    if (!_validCoordinates(lat, lng)) {
      throw StateError('Đơn hàng chưa có tọa độ điểm giao hợp lệ.');
    }
    return (lat!, lng!);
  }

  bool _validCoordinates(double? lat, double? lng) =>
      lat != null &&
      lng != null &&
      lat.isFinite &&
      lng.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180;

  ReturnRouteQuote _result({
    required (double, double) origin,
    required int distance,
    required int duration,
    required ReturnQuoteSource source,
  }) {
    final fee = DeliveryPricingPolicy.calculate(
      distanceMeters: distance.toDouble(),
    ).total.round();
    return ReturnRouteQuote(
      originLat: origin.$1,
      originLng: origin.$2,
      distanceMeters: distance,
      durationSeconds: duration,
      source: source,
      suggestedFee: fee,
    );
  }

  double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const radius = 6371000.0;
    double radians(double value) => value * math.pi / 180;
    final dLat = radians(lat2 - lat1);
    final dLng = radians(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(radians(lat1)) *
            math.cos(radians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
