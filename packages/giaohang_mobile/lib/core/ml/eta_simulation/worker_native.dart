import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'model.dart';
import 'profile.dart';

/// One model/context per isolate; only route requests cross the port thereafter.
class EtaForecastWorker {
  EtaForecastWorker._();
  final _messages = ReceivePort();
  final _errors = ReceivePort();
  final _ready = Completer<SendPort>();
  final _pending = <int, Completer<Map<String, dynamic>?>>{};
  Isolate? _isolate;
  var _sequence = 0;
  var _closed = false;

  Future<Map<String, dynamic>?> predict(
    Map<String, dynamic> route,
    String at,
  ) async {
    if (_closed) throw StateError('ETA_SIMULATION_WORKER_CLOSED');
    final port = await _ready.future;
    final id = ++_sequence;
    final result = Completer<Map<String, dynamic>?>();
    _pending[id] = result;
    port.send([id, route, at]);
    try {
      return await result.future.timeout(const Duration(seconds: 20));
    } finally {
      _pending.remove(id);
    }
  }

  void close() {
    _closed = true;
    _isolate?.kill(priority: Isolate.immediate);
    _messages.close();
    _errors.close();
    for (final result in _pending.values) {
      if (!result.isCompleted) result.complete(null);
    }
    _pending.clear();
  }
}

Future<EtaForecastWorker> createEtaForecastWorker(
  String model,
  String network,
) async {
  final worker = EtaForecastWorker._();
  worker._messages.listen((message) {
    if (message is SendPort) {
      worker._ready.complete(message);
    } else if (message is List) {
      final result = worker._pending[message[0]];
      if (result != null && !result.isCompleted) {
        result.complete(message[1] as Map<String, dynamic>?);
      }
    }
  });
  worker._errors.listen((error) {
    if (!worker._ready.isCompleted) {
      worker._ready.completeError(
        StateError('ETA_SIMULATION_WORKER_INIT_FAILED'),
      );
    }
    for (final result in worker._pending.values) {
      if (!result.isCompleted) result.complete(null);
    }
    worker.close();
  });
  try {
    worker._isolate = await Isolate.spawn(
      _run,
      [worker._messages.sendPort, model, network],
      onError: worker._errors.sendPort,
      onExit: worker._errors.sendPort,
    );
    await worker._ready.future.timeout(const Duration(seconds: 20));
    return worker;
  } catch (_) {
    worker.close();
    rethrow;
  }
}

void _run(List<dynamic> initialization) {
  final output = initialization[0] as SendPort;
  final model = EtaCorrectionModel(jsonDecode(initialization[1] as String));
  final context = Map<String, dynamic>.from(
    jsonDecode(initialization[2] as String),
  );
  final requests = ReceivePort();
  output.send(requests.sendPort);
  requests.listen((dynamic message) {
    Map<String, dynamic>? result;
    try {
      result = buildEtaProfile(
        message[1] as Map<String, dynamic>,
        message[2] as String,
        model,
        context,
      );
    } catch (_) {
      // Caller supplies the routing-baseline fallback for ETA and map.
    }
    output.send([message[0], result]);
  });
}
