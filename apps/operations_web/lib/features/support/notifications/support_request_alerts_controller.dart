import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/support_ticket.dart';
import 'support_request_alerts_repository.dart';

/// Read state belongs to the current Operations session, not case assignment.
class SupportRequestAlertsController extends ChangeNotifier {
  SupportRequestAlertsController(this.repository) {
    reconnect();
  }

  final SupportRequestAlertsRepository repository;
  StreamSubscription<List<SupportTicket>>? _subscription;
  final _known = <String>{};
  final _read = <String>{};
  List<SupportTicket> _requests = const [];
  Timer? _toastTimer;
  bool _initialized = false;
  bool _disposed = false;
  int _generation = 0;
  bool loading = true;
  bool failed = false;
  SupportTicket? latest;

  List<SupportTicket> get requests => List.unmodifiable(_requests);
  int get unreadCount =>
      _requests.where((item) => !_read.contains(item.id)).length;
  bool isUnread(String id) => !_read.contains(id);

  void reconnect() {
    final generation = ++_generation;
    unawaited(_subscription?.cancel());
    loading = true;
    failed = false;
    _subscription = repository.watchOpenRequests().listen(
      (items) {
        if (_disposed || generation != _generation) return;
        final pending =
            items
                .where(
                  (item) =>
                      item.status == SupportTicketStatus.open &&
                      item.assignedTo == null &&
                      item.needsSupportAttention,
                )
                .toList()
              ..sort(
                (left, right) => right.createdAt.compareTo(left.createdAt),
              );
        final added = pending
            .where((item) => !_known.contains(item.id))
            .toList();
        if (_initialized && added.isNotEmpty) {
          latest = added.first;
          _toastTimer?.cancel();
          _toastTimer = Timer(const Duration(seconds: 8), dismissToast);
        }
        _known.addAll(pending.map((item) => item.id));
        _requests = pending;
        if (latest != null && !pending.any((item) => item.id == latest!.id)) {
          latest = null;
          _toastTimer?.cancel();
        }
        loading = false;
        failed = false;
        _initialized = true;
        notifyListeners();
      },
      onError: (Object error) {
        if (_disposed || generation != _generation) return;
        loading = false;
        failed = true;
        notifyListeners();
      },
      onDone: () {
        if (_disposed || generation != _generation) return;
        loading = false;
        failed = true;
        notifyListeners();
      },
    );
    if (!_disposed) notifyListeners();
  }

  void markRead(String id) {
    _read.add(id);
    if (latest?.id == id) {
      latest = null;
      _toastTimer?.cancel();
    }
    notifyListeners();
  }

  void markAllRead() {
    _read.addAll(_requests.map((item) => item.id));
    dismissToast();
  }

  void dismissToast() {
    _toastTimer?.cancel();
    latest = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _toastTimer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
