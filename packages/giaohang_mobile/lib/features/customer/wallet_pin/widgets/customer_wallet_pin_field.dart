import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:giaohang_design/giaohang_design.dart';

class CustomerWalletPinField extends StatefulWidget {
  const CustomerWalletPinField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
    this.autofocus = false,
    this.onChanged,
  });
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  State<CustomerWalletPinField> createState() => _CustomerWalletPinFieldState();
}

class _CustomerWalletPinFieldState extends State<CustomerWalletPinField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_rebuild);
    widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant CustomerWalletPinField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(widget.label, style: AppTextStyles.labelLarge),
      const SizedBox(height: AppSpacing.sm),
      SizedBox(
        height: 56,
        child: Stack(
          children: [
            ExcludeSemantics(
              child: Row(
                children: List.generate(6, (index) {
                  final active =
                      widget.enabled &&
                      _focus.hasFocus &&
                      index == widget.controller.text.length.clamp(0, 5);
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                        right: index == 5 ? 0 : AppSpacing.sm,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.accentLight
                            : AppColors.bgLight,
                        borderRadius: AppRadius.md,
                        border: Border.all(
                          color: active ? AppColors.accent : AppColors.border,
                          width: active ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        index < widget.controller.text.length ? '●' : '',
                        style: AppTextStyles.headingMedium,
                      ),
                    ),
                  );
                }),
              ),
            ),
            Positioned.fill(
              child: TextField(
                key: ValueKey('${widget.key}-input'),
                controller: widget.controller,
                focusNode: _focus,
                enabled: widget.enabled,
                autofocus: widget.autofocus,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                enableInteractiveSelection: false,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: const TextStyle(color: Colors.transparent),
                cursorColor: Colors.transparent,
                decoration: InputDecoration(
                  label: Semantics(
                    label: widget.label,
                    child: const SizedBox.shrink(),
                  ),
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: false,
                  counterText: '',
                ),
                onChanged: widget.onChanged,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class CustomerWalletPinError extends StatelessWidget {
  const CustomerWalletPinError(this.message, {super.key});
  final String? message;
  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Semantics(
            liveRegion: true,
            child: Text(
              message!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        );
}
