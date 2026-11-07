import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../../core/models/customer_wallet_pin.dart';
import '../../../../core/services/customer_wallet_pin_service.dart';
import '../customer_wallet_pin_setup_screen.dart';
import '../customer_wallet_pin_strings.dart';

class CustomerWalletPinSettingsTile extends StatefulWidget {
  const CustomerWalletPinSettingsTile({super.key});
  @override
  State<CustomerWalletPinSettingsTile> createState() =>
      _CustomerWalletPinSettingsTileState();
}

class _CustomerWalletPinSettingsTileState
    extends State<CustomerWalletPinSettingsTile> {
  final _service = CustomerWalletPinService();
  late Future<CustomerWalletPinStatus> _status = _service.getStatus();

  @override
  Widget build(BuildContext context) => FutureBuilder<CustomerWalletPinStatus>(
    future: _status,
    builder: (context, snapshot) {
      final status = snapshot.data;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.pin_outlined, color: AppColors.accent),
        title: Text(
          CustomerWalletPinStrings.title,
          style: AppTextStyles.labelLarge,
        ),
        subtitle: Text(
          snapshot.hasError
              ? CustomerWalletPinStrings.loadError
              : status == null
              ? CustomerWalletPinStrings.sixDigits
              : status.isConfigured
              ? CustomerWalletPinStrings.configured
              : CustomerWalletPinStrings.unconfigured,
          style: AppTextStyles.bodySmall,
        ),
        trailing: Icon(
          snapshot.hasError
              ? Icons.refresh_rounded
              : Icons.chevron_right_rounded,
        ),
        onTap: snapshot.hasError
            ? () => setState(() => _status = _service.getStatus())
            : status == null
            ? null
            : () async {
                final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomerWalletPinSetupScreen(
                      service: _service,
                      isConfigured: status.isConfigured,
                    ),
                  ),
                );
                if (!context.mounted) return;
                setState(() => _status = _service.getStatus());
                if (saved == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(CustomerWalletPinStrings.saved),
                    ),
                  );
                }
              },
      );
    },
  );
}
