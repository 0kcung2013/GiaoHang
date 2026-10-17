import 'dart:convert';
import 'model.dart';
import 'profile.dart';

class EtaForecastWorker {
  EtaForecastWorker(String model, String context)
    : _model = EtaCorrectionModel(jsonDecode(model)),
      _context = Map<String, dynamic>.from(jsonDecode(context));
  final EtaCorrectionModel _model;
  final Map<String, dynamic> _context;
  Future<Map<String, dynamic>?> predict(
    Map<String, dynamic> route,
    String at,
  ) async => buildEtaProfile(route, at, _model, _context);
  void close() {}
}

Future<EtaForecastWorker> createEtaForecastWorker(
  String model,
  String context,
) async => EtaForecastWorker(model, context);
