import 'dart:convert';
import 'package:flutter/services.dart';
import '../constants/eta_simulation_strings.dart';
import '../ml/eta_simulation/coverage.dart';
import '../models/delivery_eta_route_profile.dart';
import '../ml/eta_simulation/worker_native.dart'
    if (dart.library.js_interop) '../ml/eta_simulation/worker_web.dart';
import '../ml/eta_simulation/profile.dart';
import 'osrm_service.dart';

/// Preview of the synthetic ETA model. Accepted orders read the server snapshot.
class EtaForecastService {
  EtaForecastService({AssetBundle? assets}) : _assets = assets ?? rootBundle;
  static final instance = EtaForecastService();
  static const modelVersion = 'hcm_synthetic_segment_speed_v2';
  static const profileVersion = 6;
  static const datasetLabel = EtaSimulationStrings.datasetLabel;
  static const datasetScope = EtaSimulationStrings.datasetScope;
  final AssetBundle _assets;
  final _cache = <String, Future<Map<String, dynamic>?>>{};
  Future<EtaForecastWorker>? _worker;

  Future<EtaForecastWorker> _load() async {
    final data = await Future.wait([
      _assets.loadString(
        'packages/giaohang_mobile/assets/ml/eta_simulation_model.json',
        cache: false,
      ),
      _assets.loadString(
        'packages/giaohang_mobile/assets/ml/eta_simulation_context.json',
        cache: false,
      ),
    ]);
    return createEtaForecastWorker(data[0], data[1]);
  }

  Future<Map<String, dynamic>?> _predict(
    Map<String, dynamic> route,
    String at,
  ) async {
    EtaForecastWorker? worker;
    try {
      worker = await (_worker ??= _load());
      return await worker.predict(route, at);
    } catch (_) {
      worker?.close();
      _worker = null;
      return null;
    }
  }

  /// Reuse only matching previews that respect the current training coverage.
  static bool canReuseForecast(OsrmRouteResult route, DateTime at) {
    final raw = route.forecastProfile;
    final profile = DeliveryEtaRouteProfile.fromJson(raw);
    if (profile == null ||
        !profile.matchesRoute(
          distanceMeters: route.distanceMeters,
          at: at,
          points: route.points,
        )) {
      return false;
    }
    final covered = EtaSimulationCoverage.containsRoute(
      route.points.map((p) => [p.longitude, p.latitude]),
    );
    if (!covered &&
        (profile.usesAi ||
            profile.fallbackReason != EtaSimulationCoverage.outsideReason)) {
      return false;
    }
    return profile.modelVersion != modelVersion ||
        (raw?['profile_version'] == profileVersion &&
            raw?['coverage_version'] == EtaSimulationCoverage.version);
  }

  Future<OsrmRouteResult> forecast(OsrmRouteResult route, DateTime at) async {
    if (route.distanceMeters <= 0 || route.points.length < 2) return route;
    final instant = at.toUtc().toIso8601String();
    if (canReuseForecast(route, at)) {
      return route;
    }
    final input = <String, dynamic>{
      'distance': route.distanceMeters,
      'duration': route.durationSeconds,
      'junction_points': [
        for (final p in route.junctionPoints) [p.longitude, p.latitude],
      ],
      'geometry': {
        'coordinates': [
          for (final p in route.points) [p.longitude, p.latitude],
        ],
      },
      'legs': [
        {
          'annotation': {
            'nodes': route.annotationNodes,
            'distance': route.annotationDistances,
            'duration': route.annotationDurations,
          },
        },
      ],
    };
    final fallback = normalizeEtaRoute(input);
    final metadata = {
      'version': modelVersion,
      'dataset_label': datasetLabel,
      'dataset_scope': datasetScope,
    };
    if (!EtaSimulationCoverage.containsRoute(
      route.points.map((p) => [p.longitude, p.latitude]),
    )) {
      return route.withForecast(
        buildEtaRoutingFallback(
          fallback,
          at.toUtc(),
          metadata,
          reason: EtaSimulationCoverage.outsideReason,
        ),
      );
    }
    final key = jsonEncode([
      modelVersion,
      profileVersion,
      EtaSimulationCoverage.version,
      instant,
      input,
    ]);
    final pending = _cache.putIfAbsent(key, () => _predict(input, instant));
    while (_cache.length > 8) {
      _cache.remove(_cache.keys.first);
    }
    final profile = await pending;
    if (profile == null) _cache.remove(key);
    return route.withForecast(
      profile ??
          buildEtaRoutingFallback(
            fallback,
            at.toUtc(),
            metadata,
            reason: 'model_unavailable',
          ),
    );
  }

  Future<void> dispose() async {
    final pending = _worker;
    _worker = null;
    _cache.clear();
    if (pending != null) {
      (await pending).close();
    }
  }
}
