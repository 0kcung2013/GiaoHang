import 'dart:async';

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/customer_wallet_pin.dart';
import '../../../core/mobile_app_role.dart';
import '../../../core/services/customer_wallet_pin_service.dart';
import '../../../core/services/customer_wallet_pin_recovery_service.dart';
import '../../help_center/screens/general_support_chat_screen.dart';
import 'customer_wallet_pin_strings.dart';
import 'widgets/customer_wallet_pin_field.dart';
import 'widgets/customer_wallet_pin_theme.dart';

Future<bool?> openCustomerWalletPinRecovery(
  BuildContext context, {
  required CustomerWalletPinService service,
}) async {
  CustomerWalletPinRecoveryService? recovery;
  try {
    final status = await service.getStatus();
    final customerId = Supabase.instance.client.auth.currentUser?.id;
    final email = status.recoveryEmail;
    if (email != null && customerId != null) {
      recovery = CustomerWalletPinRecoveryService(
        email: email,
        customerId: customerId,
      );
    }
    if (!context.mounted) return null;
    final gateway = recovery;
    return await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerWalletPinRecoveryScreen(
          email: gateway == null ? null : email,
          onSend: () async {
            await gateway?.sendCode();
          },
          onReset: (code, pin) async {
            await gateway?.resetPin(code: code, newPin: pin);
          },
        ),
      ),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(CustomerWalletPinStrings.retry)),
      );
    }
    return null;
  } finally {
    if (recovery != null) await recovery.dispose();
  }
}

class CustomerWalletPinRecoveryScreen extends StatefulWidget {
  const CustomerWalletPinRecoveryScreen({
    super.key,
    required this.email,
    required this.onSend,
    required this.onReset,
  });
  final String? email;
  final Future<void> Function() onSend;
  final Future<void> Function(String code, String pin) onReset;

  @override
  State<CustomerWalletPinRecoveryScreen> createState() =>
      _CustomerWalletPinRecoveryScreenState();
}

class _CustomerWalletPinRecoveryScreenState
    extends State<CustomerWalletPinRecoveryScreen> {
  final _code = TextEditingController();
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  Timer? _timer;
  int _seconds = 0;
  bool _sent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || _seconds > 0 || widget.email == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSend();
      if (!mounted) return;
      setState(() {
        _sent = true;
        _seconds = 60;
        _code.clear();
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _seconds <= 1) timer.cancel();
        if (mounted) setState(() => _seconds--);
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = CustomerWalletPinStrings.emailSendError);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_busy) return;
    if (_code.text.length != 6 || _pin.text.length != 6) {
      setState(() => _error = CustomerWalletPinStrings.format);
      return;
    }
    if (_pin.text != _confirm.text) {
      setState(() => _error = CustomerWalletPinStrings.mismatch);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onReset(_code.text, _pin.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is CustomerWalletPinException
              ? error.message
              : error is AuthException
              ? CustomerWalletPinStrings.invalidCode
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
            CustomerWalletPinStrings.recover,
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
                  const Icon(
                    Icons.mark_email_read_outlined,
                    color: AppColors.accent,
                    size: 48,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    widget.email == null
                        ? CustomerWalletPinStrings.emailUnavailable
                        : CustomerWalletPinStrings.recoveryHint,
                    style: AppTextStyles.bodyMedium,
                  ),
                  if (widget.email != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(widget.email!, style: AppTextStyles.labelLarge),
                    const SizedBox(height: AppSpacing.xl),
                    if (!_sent)
                      FilledButton(
                        onPressed: _busy ? null : _send,
                        child: const Text(CustomerWalletPinStrings.sendCode),
                      ),
                    if (_sent) ...[
                      Text(
                        CustomerWalletPinStrings.codeSent,
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      CustomerWalletPinField(
                        key: const ValueKey('wallet-pin-email-code'),
                        controller: _code,
                        label: CustomerWalletPinStrings.emailCode,
                        enabled: !_busy,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      CustomerWalletPinField(
                        key: const ValueKey('wallet-pin-recovery-new'),
                        controller: _pin,
                        label: CustomerWalletPinStrings.newPin,
                        enabled: !_busy,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      CustomerWalletPinField(
                        key: const ValueKey('wallet-pin-recovery-confirm'),
                        controller: _confirm,
                        label: CustomerWalletPinStrings.confirmPin,
                        enabled: !_busy,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FilledButton(
                        onPressed: _busy ? null : _reset,
                        child: const Text(CustomerWalletPinStrings.save),
                      ),
                      TextButton(
                        onPressed: _busy || _seconds > 0 ? null : _send,
                        child: Text(
                          _seconds > 0
                              ? CustomerWalletPinStrings.resendSeconds(_seconds)
                              : CustomerWalletPinStrings.resend,
                        ),
                      ),
                    ],
                  ],
                  if (_busy)
                    const LinearProgressIndicator(color: AppColors.accent),
                  CustomerWalletPinError(_error),
                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const GeneralSupportChatScreen(
                                role: MobileAppRole.customer,
                              ),
                            ),
                          ),
                    icon: const Icon(Icons.support_agent_rounded),
                    label: const Text(CustomerWalletPinStrings.support),
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
