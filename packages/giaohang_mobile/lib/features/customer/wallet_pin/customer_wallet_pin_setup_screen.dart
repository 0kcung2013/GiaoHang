import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../core/models/customer_wallet_pin.dart';
import '../../../core/services/customer_wallet_pin_service.dart';
import 'customer_wallet_pin_strings.dart';
import 'customer_wallet_pin_recovery_screen.dart';
import 'widgets/customer_wallet_pin_field.dart';
import 'widgets/customer_wallet_pin_theme.dart';

class CustomerWalletPinSetupScreen extends StatefulWidget {
  const CustomerWalletPinSetupScreen({
    super.key,
    required this.service,
    required this.isConfigured,
  });
  final CustomerWalletPinService service;
  final bool isConfigured;

  @override
  State<CustomerWalletPinSetupScreen> createState() =>
      _CustomerWalletPinSetupScreenState();
}

class _CustomerWalletPinSetupScreenState
    extends State<CustomerWalletPinSetupScreen> {
  final _current = TextEditingController();
  final _newPin = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _newPin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_newPin.text.length != 6 ||
        (widget.isConfigured && _current.text.length != 6)) {
      setState(() => _error = CustomerWalletPinStrings.format);
      return;
    }
    if (_newPin.text != _confirm.text) {
      setState(() => _error = CustomerWalletPinStrings.mismatch);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.setPin(
        _newPin.text,
        currentPin: widget.isConfigured ? _current.text : null,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is CustomerWalletPinException
              ? error.message
              : CustomerWalletPinStrings.retry,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CustomerWalletPinTheme(
    child: PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: AppColors.bgLight,
        appBar: AppBar(
          title: Text(
            widget.isConfigured
                ? CustomerWalletPinStrings.change
                : CustomerWalletPinStrings.setup,
            style: AppTextStyles.headingMedium,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screenH),
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 48,
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: AppSpacing.xl2),
                  if (widget.isConfigured) ...[
                    CustomerWalletPinField(
                      key: const ValueKey('wallet-pin-current'),
                      controller: _current,
                      label: CustomerWalletPinStrings.current,
                      enabled: !_busy,
                      autofocus: true,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  CustomerWalletPinField(
                    key: const ValueKey('wallet-pin-new'),
                    controller: _newPin,
                    label: CustomerWalletPinStrings.newPin,
                    enabled: !_busy,
                    autofocus: !widget.isConfigured,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  CustomerWalletPinField(
                    key: const ValueKey('wallet-pin-confirm'),
                    controller: _confirm,
                    label: CustomerWalletPinStrings.confirmPin,
                    enabled: !_busy,
                  ),
                  CustomerWalletPinError(_error),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.textOnAccent,
                      minimumSize: const Size.fromHeight(52),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.md,
                      ),
                    ),
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(CustomerWalletPinStrings.save),
                  ),
                  if (widget.isConfigured)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              final recovered =
                                  await openCustomerWalletPinRecovery(
                                    context,
                                    service: widget.service,
                                  );
                              if (recovered == true && context.mounted) {
                                Navigator.pop(context, true);
                              }
                            },
                      child: const Text(CustomerWalletPinStrings.forgot),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
