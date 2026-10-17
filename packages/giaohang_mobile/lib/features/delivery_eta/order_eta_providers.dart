import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/order_eta_repository.dart';
import 'models/order_eta.dart';

final orderEtaRepositoryProvider = Provider<OrderEtaRepository>(
  (ref) => OrderEtaRepository(),
);

/// One request loop per observed order, shared by all visible ETA surfaces.
final orderEtaProvider = StreamProvider.autoDispose.family<OrderEta, String>((
  ref,
  id,
) {
  final controller = StreamController<OrderEta>();
  final repository = ref.watch(orderEtaRepositoryProvider);
  var disposed = false, busy = false;
  OrderEta? last;
  Future<void> refresh() async {
    if (disposed || busy) return;
    busy = true;
    try {
      final eta = await repository.refresh(id);
      if (!disposed) {
        last = eta;
        controller.add(eta);
      }
    } catch (_) {
      if (!disposed) {
        final clock = DateTime.now();
        controller.add(
          OrderEta(
            data: last?.data,
            serverNow: last?.serverTimeAt(clock) ?? clock,
            observedAt: clock,
            issue: 'ETA_UNAVAILABLE',
          ),
        );
      }
    } finally {
      busy = false;
    }
  }

  final timer = Timer.periodic(
    const Duration(seconds: 20),
    (_) => unawaited(refresh()),
  );
  ref.onDispose(() {
    disposed = true;
    timer.cancel();
    unawaited(controller.close());
  });
  unawaited(refresh());
  return controller.stream;
});
