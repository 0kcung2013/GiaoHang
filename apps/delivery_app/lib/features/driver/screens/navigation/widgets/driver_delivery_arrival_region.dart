import 'dart:async';
import 'package:flutter/material.dart';
import '../data/driver_delivery_arrival_repository.dart';
import '../models/driver_delivery_arrival.dart';
import '../utils/driver_delivery_arrival_strings.dart';
import '../utils/driver_delivery_arrival_errors.dart';

typedef DeliveryArrivalBuilder =
    Widget Function(
      DriverDeliveryArrival? arrival,
      Duration? elapsed,
      bool loading,
      String? error,
      VoidCallback confirm,
      VoidCallback retry,
    );

/// Đồng hồ chỉ vẽ thời gian từ snapshot server; quyền báo cáo luôn do server cấp.
class DriverDeliveryArrivalRegion extends StatefulWidget {
  const DriverDeliveryArrivalRegion({
    super.key,
    required this.orderId,
    required this.builder,
    this.beforeConfirm,
    this.repository,
  });
  final String orderId;
  final DeliveryArrivalBuilder builder;
  final Future<void> Function()? beforeConfirm;
  final DriverDeliveryArrivalRepository? repository;
  @override
  State<DriverDeliveryArrivalRegion> createState() =>
      _DriverDeliveryArrivalRegionState();
}

class _DriverDeliveryArrivalRegionState
    extends State<DriverDeliveryArrivalRegion>
    with WidgetsBindingObserver {
  late DriverDeliveryArrivalRepository _repository;
  DriverDeliveryArrival? _arrival;
  final Stopwatch _clock = Stopwatch();
  Timer? _timer;
  bool _busy = false;
  String? _error;
  bool _retryConfirmation = false;
  int _ticks = 0;
  int _generation = 0;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DriverDeliveryArrivalRepository();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed = _elapsed;
      if (_arrival?.arrivedAt == null) return;
      setState(() {});
      _ticks++;
      if (_arrival?.canReport != true &&
          (_ticks % 15 == 0 ||
              (elapsed != null &&
                  elapsed >= DriverDeliveryArrival.minimumWait))) {
        unawaited(_refresh());
      }
    });
  }

  Duration? get _elapsed {
    final wait = _arrival?.elapsed;
    return wait == null ? null : wait + _clock.elapsed;
  }

  Future<void> _refresh({bool confirm = false}) async {
    if (_busy || !_active) return;
    final generation = _generation;
    final orderId = widget.orderId;
    setState(() {
      _busy = true;
      if (confirm) _error = null;
    });
    try {
      if (confirm) await widget.beforeConfirm?.call();
      if (!mounted || generation != _generation) return;
      final next = confirm
          ? await _repository.confirm(orderId)
          : await _repository.read(orderId);
      if (!mounted || widget.orderId != orderId || generation != _generation) {
        return;
      }
      setState(() {
        _arrival = next;
        _error = null;
        _retryConfirmation = false;
        _clock
          ..reset()
          ..start();
      });
    } catch (error) {
      if (mounted && widget.orderId == orderId && generation == _generation) {
        setState(() {
          _error = confirm
              ? deliveryArrivalErrorMessage(error)
              : DriverDeliveryArrivalStrings.retry;
          _retryConfirmation = confirm;
          // Không mở báo cáo bằng snapshot cũ khi mất kết nối.
          if (!confirm) _arrival = null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      if (mounted && _active && generation != _generation) {
        unawaited(_refresh());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _generation++;
    _active = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      _clock.stop();
      setState(() => _arrival = null);
      _startTimer();
      unawaited(_refresh());
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _clock.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    _arrival,
    _elapsed,
    _busy,
    _error,
    () => unawaited(_refresh(confirm: true)),
    () => unawaited(_refresh(confirm: _retryConfirmation)),
  );
}
