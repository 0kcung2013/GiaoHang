import 'dart:convert';
import 'matcher.dart';
import 'model.dart';
import 'profile.dart';

/// Web compatibility; the released Delivery app targets Android/iOS isolates.
class ForecastWorker {
  ForecastWorker(String model, String network)
    : _model = SpeedModel(jsonDecode(model)),
      _matcher = RoadMatcher(jsonDecode(network));
  final SpeedModel _model;
  final RoadMatcher _matcher;
  Future<Map<String, dynamic>?> predict(
    Map<String, dynamic> route,
    String at,
  ) async => buildRouteSpeedProfile(route, at, _model, _matcher);
  void close() {}
}

Future<ForecastWorker> createForecastWorker(
  String model,
  String network,
) async => ForecastWorker(model, network);
