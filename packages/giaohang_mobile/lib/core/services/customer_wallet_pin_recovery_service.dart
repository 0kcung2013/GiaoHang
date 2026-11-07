import 'package:giaohang_config/giaohang_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/customer_wallet_pin.dart';
import '../constants/customer_wallet_pin_messages.dart';

/// In-memory recovery client: never replaces the app's active login session.
class CustomerWalletPinRecoveryService {
  CustomerWalletPinRecoveryService({
    required this.email,
    required this.customerId,
    SupabaseClient? client,
  }) : _client =
           client ??
           SupabaseClient(
             SupabaseConstants.supabaseUrl,
             SupabaseConstants.supabaseAnonKey,
             authOptions: const AuthClientOptions(
               autoRefreshToken: false,
               authFlowType: AuthFlowType.implicit,
             ),
           );

  final String email;
  final String customerId;
  final SupabaseClient _client;
  final String _requestId = const Uuid().v4();
  bool _verified = false;

  Future<void> sendCode() async {
    _verified = false;
    if (_client.auth.currentSession != null) {
      await _client.auth.signOut(scope: SignOutScope.local);
    }
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<void> resetPin({required String code, required String newPin}) async {
    if (!_verified) {
      final result = await _client.auth.verifyOTP(
        type: OtpType.recovery,
        email: email,
        token: code,
      );
      if (result.user?.id != customerId || result.session == null) {
        throw const CustomerWalletPinException(
          CustomerWalletPinMessages.invalidIdentity,
        );
      }
      _verified = true;
    }
    CustomerWalletPinException.checkedResponse(
      await _client.rpc(
        'reset_customer_wallet_pin',
        params: {'p_new_pin': newPin, 'p_request_id': _requestId},
      ),
    );
  }

  Future<void> dispose() async {
    try {
      if (_client.auth.currentSession != null) {
        await _client.auth.signOut(scope: SignOutScope.local);
      }
    } catch (_) {
      // A failed sign-out must not prevent disposal of the in-memory client.
    } finally {
      await _client.dispose();
    }
  }
}
