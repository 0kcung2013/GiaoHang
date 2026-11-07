import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_wallet_pin.dart';
import 'customer_wallet_service.dart';

class CustomerWalletPinService {
  CustomerWalletPinService({
    SupabaseClient? client,
    CustomerWalletRpcInvoker? rpcInvoker,
  }) : _invoke =
           rpcInvoker ??
           ((name, params) =>
               (client ?? Supabase.instance.client).rpc(name, params: params));

  final CustomerWalletRpcInvoker _invoke;

  Future<CustomerWalletPinStatus> getStatus() async {
    final json = CustomerWalletPinException.checkedResponse(
      await _invoke('get_customer_wallet_pin_status', const {}),
    );
    return CustomerWalletPinStatus.fromJson(json);
  }

  Future<void> setPin(String newPin, {String? currentPin}) async {
    CustomerWalletPinException.checkedResponse(
      await _invoke('set_customer_wallet_pin', {
        'p_new_pin': newPin,
        'p_current_pin': currentPin,
      }),
    );
  }
}
