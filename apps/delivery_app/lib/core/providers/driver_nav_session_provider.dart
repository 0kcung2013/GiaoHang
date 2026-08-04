import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lưu tiến trình điều hướng theo orderId.
/// Persist SharedPreferences để **hot restart (Shift+R)** không mất vị trí.
class DriverNavSession {
  const DriverNavSession({
    required this.orderId,
    required this.status,
    required this.lat,
    required this.lng,
    this.arrivedAtTarget = false,
    this.pickupConfirmed = false,
    this.simRouteIndex = 0,
    this.updatedAt,
  });

  final String orderId;
  final String status;
  final double lat;
  final double lng;
  final bool arrivedAtTarget;
  final bool pickupConfirmed;
  final int simRouteIndex;
  final DateTime? updatedAt;

  bool canRestoreFor({
    required String activeOrderId,
    required String activeStatus,
  }) {
    const activeStatuses = {'assigned', 'picking_up', 'delivering'};
    final hasValidCoordinates =
        lat.isFinite &&
        lng.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180 &&
        (lat != 0 || lng != 0);

    return orderId == activeOrderId &&
        activeStatuses.contains(activeStatus) &&
        hasValidCoordinates;
  }

  DriverNavSession copyWith({
    String? orderId,
    String? status,
    double? lat,
    double? lng,
    bool? arrivedAtTarget,
    bool? pickupConfirmed,
    int? simRouteIndex,
    DateTime? updatedAt,
  }) {
    return DriverNavSession(
      orderId: orderId ?? this.orderId,
      status: status ?? this.status,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      arrivedAtTarget: arrivedAtTarget ?? this.arrivedAtTarget,
      pickupConfirmed: pickupConfirmed ?? this.pickupConfirmed,
      simRouteIndex: simRouteIndex ?? this.simRouteIndex,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'status': status,
    'lat': lat,
    'lng': lng,
    'arrivedAtTarget': arrivedAtTarget,
    'pickupConfirmed': pickupConfirmed,
    'simRouteIndex': simRouteIndex,
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory DriverNavSession.fromJson(Map<String, dynamic> json) {
    return DriverNavSession(
      orderId: json['orderId']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      arrivedAtTarget: json['arrivedAtTarget'] == true,
      pickupConfirmed: json['pickupConfirmed'] == true,
      simRouteIndex: (json['simRouteIndex'] as num?)?.toInt() ?? 0,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }
}

const _prefsKey = 'driver_nav_sessions_v1';

/// orderId → session (memory + disk).
final driverNavSessionsProvider =
    StateNotifierProvider<
      DriverNavSessionsNotifier,
      Map<String, DriverNavSession>
    >((ref) => DriverNavSessionsNotifier()..hydrate());

class DriverNavSessionsNotifier
    extends StateNotifier<Map<String, DriverNavSession>> {
  DriverNavSessionsNotifier() : super(const {});

  final _hydrated = Completer<void>();

  /// Chờ đọc xong SharedPreferences (hot restart).
  Future<void> get ready => _hydrated.future;

  Future<void> hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final out = <String, DriverNavSession>{};
        for (final e in map.entries) {
          if (e.value is Map) {
            out[e.key] = DriverNavSession.fromJson(
              Map<String, dynamic>.from(e.value as Map),
            );
          }
        }
        if (out.isNotEmpty) state = out;
      }
    } catch (_) {
      // ignore corrupt prefs
    } finally {
      if (!_hydrated.isCompleted) _hydrated.complete();
    }
  }

  Future<void> upsert(DriverNavSession session) async {
    state = {...state, session.orderId: session};
    await _persist();
  }

  Future<void> remove(String orderId) async {
    final next = Map<String, DriverNavSession>.from(state)..remove(orderId);
    state = next;
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = {for (final e in state.entries) e.key: e.value.toJson()};
      await prefs.setString(_prefsKey, jsonEncode(encoded));
    } catch (_) {}
  }
}
