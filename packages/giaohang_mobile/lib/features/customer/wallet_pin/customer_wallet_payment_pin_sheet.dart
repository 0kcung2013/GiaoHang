import 'dart:async';

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../core/models/customer_wallet_pin.dart';
import '../../../core/services/customer_wallet_pin_service.dart';
import '../../../core/utils/money_formatter.dart';
import 'customer_wallet_pin_recovery_screen.dart';
import 'customer_wallet_pin_setup_screen.dart';
import 'customer_wallet_pin_strings.dart';
import 'widgets/customer_wallet_pin_field.dart';
import 'widgets/customer_wallet_pin_theme.dart';

Future<bool?> showCustomerWalletPaymentPinSheet(
  BuildContext context, {
  required CustomerWalletPinService service,
  required int amount,
  required int? balance,
  required Future<void> Function(String) onConfirm,
}) async {
  var status = await service.getStatus();
  if (!context.mounted) return null;
  if (!status.isConfigured) {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CustomerWalletPinSetupScreen(service: service, isConfigured: false),
      ),
    );
    if (saved != true || !context.mounted) return null;
    status = await service.getStatus();
  }
  if (!context.mounted) return null;
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => CustomerWalletPaymentPinSheet(
      status: status,
      amount: amount,
      balance: balance,
      onConfirm: onConfirm,
      onRecover: () => openCustomerWalletPinRecovery(context, service: service),
    ),
  );
}

class CustomerWalletPaymentPinSheet extends StatefulWidget {
  const CustomerWalletPaymentPinSheet({
    super.key,
    required this.status,
    required this.amount,
    required this.balance,
    required this.onConfirm,
    required this.onRecover,
  });
  final CustomerWalletPinStatus status;
  final int amount;
  final int? balance;
  final Future<void> Function(String) onConfirm;
  final Future<bool?> Function() onRecover;

  @override
  State<CustomerWalletPaymentPinSheet> createState() =>
      _CustomerWalletPaymentPinSheetState();
}

class _CustomerWalletPaymentPinSheetState
    extends State<CustomerWalletPaymentPinSheet> {
  final _pin = TextEditingController();
  bool _busy = false;
  String? _error;
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.status.isLocked) {
      _lock(widget.status.lockRemaining);
      _error = CustomerWalletPinStrings.lockMinutes(
        (_remaining.inSeconds / 60).ceil(),
      );
    }
  }

  void _lock(Duration duration) {
    _remaining = duration;
    _timer?.cancel();
    final stopwatch = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _remaining = duration - stopwatch.elapsed;
        if (_remaining <= Duration.zero) {
          timer.cancel();
          _error = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_busy || _pin.text.length != 6 || _remaining > Duration.zero) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onConfirm(_pin.text);
      _pin.clear();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is CustomerWalletPinException
            ? error.message
            : CustomerWalletPinStrings.retry;
        if (error is CustomerWalletPinException && error.code == 'PIN_LOCKED') {
          _lock(error.lockRemaining ?? const Duration(minutes: 15));
        }
        _pin.clear();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CustomerWalletPinTheme(
    child: PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.accent,
                      size: 32,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      CustomerWalletPinStrings.confirmPayment,
                      style: AppTextStyles.headingMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      CustomerWalletPinStrings.amount,
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      formatVnd(widget.amount),
                      style: AppTextStyles.displayMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (widget.balance != null &&
                        widget.balance! >= widget.amount)
                      Text(
                        '${CustomerWalletPinStrings.remaining}: ${formatVnd(widget.balance! - widget.amount)}',
                        style: AppTextStyles.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: AppSpacing.xl2),
                    CustomerWalletPinField(
                      key: const ValueKey('wallet-payment-pin'),
                      controller: _pin,
                      label: CustomerWalletPinStrings.pin,
                      enabled: !_busy && _remaining <= Duration.zero,
                      autofocus: !widget.status.isLocked,
                      onChanged: (_) => setState(() {}),
                    ),
                    CustomerWalletPinError(_error),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              try {
                                final recovered = await widget.onRecover();
                                if (mounted && recovered == true) {
                                  setState(() {
                                    _timer?.cancel();
                                    _remaining = Duration.zero;
                                    _error = null;
                                    _pin.clear();
                                  });
                                }
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                            },
                      child: const Text(CustomerWalletPinStrings.forgot),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.textOnAccent,
                        minimumSize: const Size.fromHeight(52),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.md,
                        ),
                      ),
                      onPressed:
                          _busy ||
                              _remaining > Duration.zero ||
                              _pin.text.length != 6
                          ? null
                          : _confirm,
                      child: _busy
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(CustomerWalletPinStrings.confirmPayment),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.pop(context, false),
                      child: const Text(CustomerWalletPinStrings.cancel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
