import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pickup_handoff_strings.dart';

final pickupHandoffServiceProvider = Provider<PickupHandoffService>(
  (ref) => PickupHandoffService(),
);

class PickupHandoffCode {
  const PickupHandoffCode({
    this.code,
    this.expiresAt,
    this.driverId,
    this.confirmedAt,
    required this.serverNow,
  });

  final String? code;
  final DateTime? expiresAt;
  final String? driverId;
  final DateTime? confirmedAt;
  final DateTime serverNow;

  factory PickupHandoffCode.fromJson(Map<String, dynamic> json) {
    final code = json['code'] as String?;
    final expiresAt = DateTime.tryParse(json['expires_at']?.toString() ?? '');
    final confirmedAt = DateTime.tryParse(
      json['confirmed_at']?.toString() ?? '',
    );
    final serverNow = DateTime.tryParse(json['server_now']?.toString() ?? '');
    if (serverNow == null ||
        (confirmedAt == null &&
            (code == null ||
                !RegExp(r'^\d{4}$').hasMatch(code) ||
                expiresAt == null))) {
      throw const PickupHandoffException(PickupHandoffStrings.loadFailure);
    }
    return PickupHandoffCode(
      code: code,
      expiresAt: expiresAt,
      driverId: json['driver_id'] as String?,
      confirmedAt: confirmedAt,
      serverNow: serverNow,
    );
  }
}

class PickupHandoffException implements Exception {
  const PickupHandoffException(this.message);
  final String message;

  @override
  String toString() => message;
}

class PickupHandoffService {
  PickupHandoffService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<PickupHandoffCode> getCustomerCode(String orderId) async {
    final result = await _client.rpc(
      'get_customer_pickup_code',
      params: {'p_order_id': orderId},
    );
    return PickupHandoffCode.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<void> confirmPickup({
    required String orderId,
    required String code,
  }) async {
    if (!RegExp(r'^\d{4}$').hasMatch(code)) {
      throw const PickupHandoffException(PickupHandoffStrings.codeRequired);
    }
    final result = await _client.rpc(
      'confirm_driver_pickup_code',
      params: {'p_order_id': orderId, 'p_code': code},
    );
    if (result is! Map) {
      throw const PickupHandoffException(
        PickupHandoffStrings.confirmationFailure,
      );
    }
    if (result['success'] != true) {
      final message = switch (result['error']) {
        'PICKUP_CODE_INVALID' => PickupHandoffStrings.codeInvalid,
        'PICKUP_CODE_LOCKED' => PickupHandoffStrings.codeLocked,
        'PICKUP_CODE_EXPIRED' => PickupHandoffStrings.codeExpired,
        _ => PickupHandoffStrings.confirmationFailure,
      };
      throw PickupHandoffException(message);
    }
    if (result['new_status'] != 'delivering' ||
        DateTime.tryParse(result['confirmed_at']?.toString() ?? '') == null) {
      throw const PickupHandoffException(
        PickupHandoffStrings.confirmationFailure,
      );
    }
  }
}
