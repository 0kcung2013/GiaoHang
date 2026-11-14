import 'package:giaohang_config/giaohang_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class PasswordRecoveryGateway {
  Future<void> sendCode(String email);
  Future<void> verifyCode(String email, String code);
  Future<void> updatePassword(String password);
  Future<void> dispose();
}

/// Recovery stays in memory and never emits auth events on the app's client.
class PasswordRecoveryService implements PasswordRecoveryGateway {
  PasswordRecoveryService({SupabaseClient? client})
    : _client =
          client ??
          SupabaseClient(
            SupabaseConstants.supabaseUrl,
            SupabaseConstants.supabaseAnonKey,
            authOptions: const AuthClientOptions(
              autoRefreshToken: false,
              authFlowType: AuthFlowType.implicit,
            ),
          );

  final SupabaseClient _client;
  String? _verifiedEmail;
  Future<void>? _pending;
  Future<void>? _disposal;
  bool _closed = false;
  bool _busy = false;

  @override
  Future<void> sendCode(String email) => _run(() async {
    _verifiedEmail = null;
    await _signOut();
    await _client.auth.resetPasswordForEmail(email.trim());
  });

  @override
  Future<void> verifyCode(String email, String code) => _run(() async {
    _verifiedEmail = null;
    final response = await _client.auth.verifyOTP(
      email: email.trim(),
      token: code.trim(),
      type: OtpType.recovery,
    );
    if (response.session == null ||
        response.user?.email?.toLowerCase() != email.trim().toLowerCase()) {
      await _signOut();
      throw const AuthException('Invalid recovery proof', code: 'otp_expired');
    }
    _verifiedEmail = email.trim().toLowerCase();
  });

  @override
  Future<void> updatePassword(String password) => _run(() async {
    if (_verifiedEmail == null ||
        _client.auth.currentSession == null ||
        _client.auth.currentUser?.email?.toLowerCase() != _verifiedEmail) {
      throw const AuthException('Recovery required', code: 'session_expired');
    }
    await _client.auth.updateUser(UserAttributes(password: password));
    _verifiedEmail = null;
    // A logout failure must not turn a successful password change into an error.
    try {
      await _signOut();
    } catch (_) {
      // dispose retries cleanup and always discards this in-memory client.
    }
  });

  Future<void> _signOut() async {
    if (_client.auth.currentSession != null) {
      await _client.auth.signOut(scope: SignOutScope.local);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_closed || _busy) throw StateError('Recovery client is unavailable');
    _busy = true;
    try {
      final pending = action();
      _pending = pending;
      await pending;
    } finally {
      _busy = false;
    }
  }

  @override
  Future<void> dispose() {
    _closed = true;
    return _disposal ??= _dispose();
  }

  Future<void> _dispose() async {
    // Closing during /verify must still clean up the session it returns later.
    try {
      await _pending;
    } catch (_) {
      // The caller handles the operation error.
    }
    _verifiedEmail = null;
    try {
      await _signOut();
    } catch (_) {
      // Never retain a local recovery session when the network is unavailable.
    } finally {
      await _client.dispose();
    }
  }
}
