import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/models/order_model.dart';
import '../driver_home_strings.dart';
import 'driver_incoming_offer_overlay.dart';

typedef _OfferContent = ({OrderModel order, LatLng? position});

/// Một lời mời trên root Navigator, phía trên mọi tab, drawer và màn hình phụ.
/// Navigator con giữ sheet xác nhận trong vòng đời của chính lời mời đó.
class DriverIncomingOfferHost extends StatefulWidget {
  const DriverIncomingOfferHost({
    super.key,
    required this.order,
    required this.driverUserId,
    required this.now,
    this.driverPosition,
  });

  final OrderModel? order;
  final String driverUserId;
  final DateTime Function()? now;
  final LatLng? driverPosition;

  @override
  State<DriverIncomingOfferHost> createState() =>
      _DriverIncomingOfferHostState();
}

class _DriverIncomingOfferHostState extends State<DriverIncomingOfferHost> {
  PageRoute<void>? _route;
  ValueNotifier<_OfferContent>? _content;
  String? _offerKey;
  String? _resolvedOfferKey;
  String? _lastAlertedOfferKey;
  Timer? _expiry;
  bool _syncScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleSync();
  }

  @override
  void didUpdateWidget(covariant DriverIncomingOfferHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleSync();
  }

  void _scheduleSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (mounted) _syncOffer();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _syncOffer() {
    _expiry?.cancel();
    final order = widget.order;
    final now = widget.now;
    if (order == null ||
        now == null ||
        !order.isOfferedToDriverAt(widget.driverUserId, now())) {
      _closeOffer();
      return;
    }
    final key = '${widget.driverUserId}/${order.id}/${order.offerExpiresAt}';
    if (key == _resolvedOfferKey) return;
    if (_offerKey != key) {
      _closeOffer();
      final content = ValueNotifier<_OfferContent>((
        order: order,
        position: widget.driverPosition,
      ));
      final driverUserId = widget.driverUserId;
      final route = PageRouteBuilder<void>(
        settings: const RouteSettings(
          name: DriverHomeStrings.incomingOfferRoute,
        ),
        fullscreenDialog: true,
        transitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : AppDuration.fast,
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        pageBuilder: (_, _, _) => PopScope(
          canPop: false,
          child: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => ValueListenableBuilder<_OfferContent>(
                valueListenable: content,
                builder: (_, value, _) => DriverIncomingOfferOverlay(
                  key: ValueKey(key),
                  order: value.order,
                  driverUserId: driverUserId,
                  driverPosition: value.position,
                  onResolved: () {
                    // Không gỡ nhầm lời mời kế tiếp nếu HTTP cũ trả về muộn.
                    _resolvedOfferKey = key;
                    if (_offerKey == key) _closeOffer();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      _route = route;
      _offerKey = key;
      _content = content;
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.of(context, rootNavigator: true).push(route);
      // Chờ cả Navigator con (sheet) tháo khỏi tree rồi mới hủy notifier.
      unawaited(route.completed.then((_) => content.dispose()));
      if (_lastAlertedOfferKey != key) {
        _lastAlertedOfferKey = key;
        unawaited(_playArrivalFeedback());
      }
    } else {
      _content!.value = (order: order, position: widget.driverPosition);
    }
    final deadline = order.offerExpiresAt!.isBefore(order.assignmentDeadline)
        ? order.offerExpiresAt!
        : order.assignmentDeadline;
    _expiry = Timer(deadline.difference(now()), _syncOffer);
  }

  void _closeOffer() {
    _expiry?.cancel();
    final route = _route;
    _route = null;
    _content = null;
    _offerKey = null;
    if (route?.isActive == true) route!.navigator?.removeRoute(route);
  }

  Future<void> _playArrivalFeedback() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      // Nền tảng không hỗ trợ âm báo vẫn có thể rung.
    }
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {
      // Thiết bị không hỗ trợ rung vẫn hiển thị lời mời.
    }
  }

  @override
  void dispose() {
    _expiry?.cancel();
    final route = _route;
    // dispose có thể chạy khi Navigator đang khóa trong một frame điều hướng.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route?.isActive == true && route?.navigator?.mounted == true) {
        route!.navigator!.removeRoute(route);
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
