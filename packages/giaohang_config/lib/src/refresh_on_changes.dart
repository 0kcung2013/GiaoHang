import 'dart:async';

/// Subscribe before fetching, serialize requests, and retain one pending refresh.
/// Errors do not end the stream: reconnect/resume can recover without reopening UI.
Stream<T> refreshOnChanges<T>(Stream<void> changes, Future<T> Function() load) {
  late final StreamController<T> controller;
  StreamSubscription<void>? subscription;
  var cancelled = false;
  var running = false;
  var pending = false;

  Future<void> refresh() async {
    if (cancelled) return;
    pending = true;
    if (running) return;
    running = true;
    while (pending && !cancelled) {
      pending = false;
      try {
        final value = await load();
        if (!cancelled) controller.add(value);
      } catch (error, stack) {
        if (!cancelled) controller.addError(error, stack);
      }
    }
    running = false;
  }

  controller = StreamController<T>(
    onListen: () {
      subscription = changes.listen(
        (_) => unawaited(refresh()),
        onError: (Object error, StackTrace stack) {
          if (!cancelled) controller.addError(error, stack);
        },
      );
      unawaited(refresh());
    },
    onCancel: () async {
      cancelled = true;
      await subscription?.cancel();
    },
  );
  return controller.stream;
}
