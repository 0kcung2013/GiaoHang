import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:giaohang_design/giaohang_design.dart';
import 'driver_online_pin_input.dart';

typedef DriverOnlinePinVerifier = Future<void> Function(String pin);

Future<String?> showDriverOnlinePinVerificationSheet(
  BuildContext context, {
  required bool isSetup,
  required DriverOnlinePinVerifier onVerify,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.primary.withValues(alpha: 0.62),
    builder: (_) =>
        DriverOnlinePinVerificationSheet(isSetup: isSetup, onVerify: onVerify),
  );
}

class DriverOnlinePinVerificationSheet extends StatefulWidget {
  const DriverOnlinePinVerificationSheet({
    super.key,
    required this.isSetup,
    required this.onVerify,
  });

  final bool isSetup;
  final DriverOnlinePinVerifier onVerify;

  @override
  State<DriverOnlinePinVerificationSheet> createState() =>
      _DriverOnlinePinVerificationSheetState();
}

class _DriverOnlinePinVerificationSheetState
    extends State<DriverOnlinePinVerificationSheet> {
  final _pinController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _pinFocusNode = FocusNode();
  final _confirmationFocusNode = FocusNode();

  bool _obscurePin = true;
  bool _isVerifying = false;
  String? _errorMessage;
  String? _lastAttempt;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmationController.dispose();
    _pinFocusNode.dispose();
    _confirmationFocusNode.dispose();
    super.dispose();
  }

  void _handlePinChanged(String value) {
    _clearErrorWhileEditing();
    if (value.length < 6) {
      _lastAttempt = null;
      return;
    }

    if (widget.isSetup) {
      if (_confirmationController.text.length < 6) {
        _confirmationFocusNode.requestFocus();
        return;
      }
      _validateSetupAndVerify();
      return;
    }
    _verify(value);
  }

  void _handleConfirmationChanged(String value) {
    _clearErrorWhileEditing();
    if (value.length < 6) {
      _lastAttempt = null;
      return;
    }
    _validateSetupAndVerify();
  }

  void _clearErrorWhileEditing() {
    if (_errorMessage == null || _isVerifying) return;
    setState(() => _errorMessage = null);
  }

  void _validateSetupAndVerify() {
    final pin = _pinController.text;
    final confirmation = _confirmationController.text;
    if (pin.length != 6 || confirmation.length != 6) return;

    if (pin != confirmation) {
      HapticFeedback.mediumImpact();
      setState(() => _errorMessage = 'Hai mã PIN chưa khớp. Hãy nhập lại.');
      _confirmationController.clear();
      _confirmationFocusNode.requestFocus();
      return;
    }
    _verify(pin);
  }

  Future<void> _verify(String pin) async {
    final attempt = widget.isSetup
        ? '$pin:${_confirmationController.text}'
        : pin;
    if (_isVerifying || _lastAttempt == attempt) return;

    _lastAttempt = attempt;
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      await widget.onVerify(pin);
      if (!mounted) return;
      Navigator.of(context).pop(pin);
    } catch (error) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      setState(() {
        _isVerifying = false;
        _errorMessage = message.isEmpty
            ? 'Không thể xác thực mã PIN. Vui lòng thử lại.'
            : message;
      });

      _lastAttempt = null;
      if (widget.isSetup) {
        _confirmationController.clear();
        _confirmationFocusNode.requestFocus();
      } else {
        _pinController.clear();
        _pinFocusNode.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final title = widget.isSetup ? 'Tạo mã PIN Online' : 'Xác thực để Online';
    final subtitle = widget.isSetup
        ? 'Tạo 6 số bảo vệ thao tác nhận đơn.'
        : 'Nhập đủ 6 số để kiểm tra ngay.';

    return AnimatedPadding(
      duration: AppDuration.normal,
      curve: AppCurve.decelerate,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Material(
        color: AppColors.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.md,
            AppSpacing.screenH,
            AppSpacing.xl2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.border,
                    borderRadius: AppRadius.full,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: AppRadius.lg,
                    ),
                    child: const Icon(
                      Icons.password_rounded,
                      color: AppColors.accent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.headingLarge.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          subtitle,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: _isVerifying
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl2),
              DriverOnlinePinField(
                inputKey: const ValueKey('driver-online-pin'),
                controller: _pinController,
                focusNode: _pinFocusNode,
                label: widget.isSetup ? 'Mã PIN mới' : 'Mã PIN Online',
                obscureText: _obscurePin,
                autofocus: true,
                enabled: !_isVerifying,
                hasError: _errorMessage != null && !widget.isSetup,
                textInputAction: widget.isSetup
                    ? TextInputAction.next
                    : TextInputAction.done,
                onChanged: _handlePinChanged,
                onToggleVisibility: () {
                  setState(() => _obscurePin = !_obscurePin);
                },
              ),
              if (widget.isSetup) ...[
                const SizedBox(height: AppSpacing.lg),
                DriverOnlinePinField(
                  inputKey: const ValueKey('driver-online-pin-confirmation'),
                  controller: _confirmationController,
                  focusNode: _confirmationFocusNode,
                  label: 'Nhập lại mã PIN',
                  obscureText: _obscurePin,
                  enabled: !_isVerifying,
                  hasError: _errorMessage != null,
                  textInputAction: TextInputAction.done,
                  onChanged: _handleConfirmationChanged,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              AnimatedSwitcher(
                duration: AppDuration.fast,
                child: DriverOnlinePinStatus(
                  key: ValueKey((_isVerifying, _errorMessage)),
                  isVerifying: _isVerifying,
                  errorMessage: _errorMessage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
