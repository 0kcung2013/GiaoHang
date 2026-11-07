import '../constants/customer_wallet_pin_messages.dart';

class CustomerWalletPinStatus {
  const CustomerWalletPinStatus({
    required this.isConfigured,
    required this.attemptsRemaining,
    required this.serverNow,
    this.lockedUntil,
    this.recoveryEmail,
  });

  final bool isConfigured;
  final int attemptsRemaining;
  final DateTime serverNow;
  final DateTime? lockedUntil;
  final String? recoveryEmail;

  Duration get lockRemaining =>
      lockedUntil == null ? Duration.zero : lockedUntil!.difference(serverNow);
  bool get isLocked => lockRemaining > Duration.zero;

  Map<String, dynamic> toJson() => {
    'is_configured': isConfigured,
    'attempts_remaining': attemptsRemaining,
    'server_now': serverNow.toIso8601String(),
    'locked_until': lockedUntil?.toIso8601String(),
    'recovery_email': recoveryEmail,
  };

  factory CustomerWalletPinStatus.fromJson(Map<String, dynamic> json) =>
      CustomerWalletPinStatus(
        isConfigured: json['is_configured'] == true,
        attemptsRemaining: (json['attempts_remaining'] as num?)?.toInt() ?? 5,
        serverNow: DateTime.parse(json['server_now'] as String),
        lockedUntil: DateTime.tryParse(json['locked_until']?.toString() ?? ''),
        recoveryEmail: json['recovery_email'] as String?,
      );
}

class CustomerWalletPinException implements Exception {
  const CustomerWalletPinException(
    this.message, {
    this.code = 'PIN_ERROR',
    this.lockRemaining,
  });

  final String message;
  final String code;
  final Duration? lockRemaining;

  factory CustomerWalletPinException.fromJson(Map<String, dynamic> json) {
    final code = json['code']?.toString() ?? 'PIN_ERROR';
    final remaining = (json['attempts_remaining'] as num?)?.toInt() ?? 0;
    final serverNow = DateTime.tryParse(json['server_now']?.toString() ?? '');
    final until = DateTime.tryParse(json['locked_until']?.toString() ?? '');
    final lock = serverNow == null || until == null
        ? null
        : until.difference(serverNow);
    final minutes = lock == null
        ? 15
        : (lock.inSeconds / 60).ceil().clamp(1, 15);
    return CustomerWalletPinException(
      switch (code) {
        'PIN_REQUIRED' => CustomerWalletPinMessages.required,
        'PIN_FORMAT' => CustomerWalletPinMessages.format,
        'PIN_INVALID' => CustomerWalletPinMessages.invalid(remaining),
        'PIN_LOCKED' => CustomerWalletPinMessages.locked(minutes),
        'EMAIL_VERIFICATION_REQUIRED' =>
          CustomerWalletPinMessages.verificationRequired,
        _ => CustomerWalletPinMessages.retry,
      },
      code: code,
      lockRemaining: lock,
    );
  }

  static Map<String, dynamic> checkedResponse(dynamic response) {
    if (response is! Map) {
      throw const CustomerWalletPinException(
        CustomerWalletPinMessages.invalidResponse,
      );
    }
    final json = Map<String, dynamic>.from(response);
    if (json['ok'] != true) throw CustomerWalletPinException.fromJson(json);
    return json;
  }

  @override
  String toString() => message;
}
