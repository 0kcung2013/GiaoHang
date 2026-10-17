import 'dart:convert';
import 'package:flutter/services.dart';
import '../ml/utraffic/worker_native.dart'
    if (dart.library.js_interop) '../ml/utraffic/worker_web.dart';
import 'osrm_service.dart';

/// Preview only. Assigned orders always consume the stored server snapshot.
class UtrafficForecastService {
  UtrafficForecastService({AssetBundle? assets})
    : _assets = assets ?? rootBundle;
  static final instance = UtrafficForecastService();
  static const modelVersion = 'hcm_utraffic_segment_speed_v1';
  static const datasetLabel = 'UTraffic TP.HCM';
  static const datasetScope = 'Vận tốc dự báo từ dữ liệu lịch sử';
  final AssetBundle _assets;
  final _cache = <String, Future<Map<String, dynamic>?>>{};
  Future<ForecastWorker>? _worker;

  Future<ForecastWorker> _load() async {
    final data = await Future.wait([
      _assets.loadString('packages/giaohang_mobile/assets/ml/utraffic_model.json', cache: false),
      _assets.loadString('packages/giaohang_mobile/assets/ml/utraffic_network.json', cache: false),
    ]);
    return createForecastWorker(data[0], data[1]);
  }

  Future<Map<String, dynamic>?> _predict(
    Map<String, dynamic> route,
    String at,
  ) async {
    ForecastWorker? worker;
    try {
      worker = await (_worker ??= _load());
      return await worker.predict(route, at);
    } catch (_) {
      worker?.close();
      _worker = null;
      return null;
    }
  }

  Future<OsrmRouteResult> forecast(OsrmRouteResult route, DateTime at) async {
    if (route.distanceMeters <= 0 || route.points.length < 2) return route;
    final instant = at.toUtc().toIso8601String();
    if (DateTime.tryParse(
              route.forecastProfile?['forecast_at']?.toString() ?? '',
            )?.isAtSameMomentAs(at) ==
            true &&
        route.forecastProfile?['model_version'] == modelVersion) {
      return route;
    }
    final input = <String, dynamic>{
      'distance': route.distanceMeters,
      'geometry': {
        'coordinates': [
          for (final p in route.points) [p.longitude, p.latitude],
        ],
      },
      'legs': [
        {
          'annotation': {'nodes': route.annotationNodes},
        },
      ],
    };
    final key = jsonEncode([modelVersion, instant, input]);
    final pending = _cache.putIfAbsent(key, () => _predict(input, instant));
    while (_cache.length > 8) {
      _cache.remove(_cache.keys.first);
    }
    final profile = await pending;
    if (profile == null) _cache.remove(key);
    return route.withForecast(
      profile ??
          {
            'model_version': modelVersion,
            'forecast_at': instant,
            'distance_meters': route.distanceMeters,
            'route_points': (input['geometry'] as Map)['coordinates'],
            'travel_minutes': route.distanceMeters * .06 / 25,
            'used_ai': false,
            'ai_coverage_ratio': 0.0,
            'speed_profile': [
              {
                'start_meters': 0.0,
                'end_meters': route.distanceMeters,
                'speed_kmh': 25.0,
                'used_ai': false,
              },
            ],
          },
    );
  }

  Future<void> dispose() async {
    final pending = _worker;
    _worker = null;
    _cache.clear();
    if (pending != null) {
      try {
        (await pending).close();
      } catch (_) {}
    }
  }
}
