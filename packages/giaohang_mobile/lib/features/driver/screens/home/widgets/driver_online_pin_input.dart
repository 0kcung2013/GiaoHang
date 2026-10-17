import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:giaohang_design/giaohang_design.dart';

class DriverOnlinePinField extends StatefulWidget {
  const DriverOnlinePinField({
    super.key,
    required this.inputKey,
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.obscureText,
    required this.enabled,
    required this.hasError,
    required this.textInputAction,
    required this.onChanged,
    this.autofocus = false,
    this.onToggleVisibility,
  });

  final Key inputKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final bool obscureText;
  final bool enabled;
  final bool hasError;
  final TextInputAction textInputAction;
  final ValueChanged<String> onChanged;
  final bool autofocus;
  final VoidCallback? onToggleVisibility;

  @override
  State<DriverOnlinePinField> createState() => DriverOnlinePinFieldState();
}

class DriverOnlinePinFieldState extends State<DriverOnlinePinField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
    widget.focusNode.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant DriverOnlinePinField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_rebuild);
      widget.focusNode.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    widget.focusNode.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text;
    final activeIndex = value.length.clamp(0, 5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (widget.onToggleVisibility != null)
              IconButton(
                tooltip: widget.obscureText ? 'Hiện mã PIN' : 'Ẩn mã PIN',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onToggleVisibility,
                icon: Icon(
                  widget.obscureText
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 58,
          child: Stack(
            children: [
              Row(
                children: List.generate(6, (index) {
                  final hasValue = index < value.length;
                  final isActive =
                      widget.focusNode.hasFocus &&
                      (index == activeIndex || value.length == 6 && index == 5);
                  final borderColor = widget.hasError
                      ? AppColors.error
                      : isActive
                      ? AppColors.accent
                      : hasValue
                      ? AppColors.primary.withValues(alpha: 0.42)
                      : AppColors.border;

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: index == 5 ? 0 : AppSpacing.sm,
                      ),
                      child: AnimatedContainer(
                        key: const ValueKey('driver-online-pin-digit'),
                        duration: AppDuration.fast,
                        curve: AppCurve.decelerate,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: widget.hasError
                              ? AppColors.error.withValues(alpha: 0.05)
                              : isActive
                              ? AppColors.accentLight
                              : AppColors.bgLight,
                          borderRadius: AppRadius.md,
                          border: Border.all(
                            color: borderColor,
                            width: isActive ? 1.8 : 1.2,
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: AppDuration.fast,
                          child: Text(
                            hasValue
                                ? widget.obscureText
                                      ? '●'
                                      : value[index]
                                : '',
                            key: ValueKey(
                              '$index-${hasValue ? value[index] : ''}',
                            ),
                            style: AppTextStyles.headingMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0.01,
                  child: TextField(
                    key: widget.inputKey,
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    autofocus: widget.autofocus,
                    enabled: widget.enabled,
                    obscureText: widget.obscureText,
                    obscuringCharacter: '●',
                    keyboardType: TextInputType.number,
                    textInputAction: widget.textInputAction,
                    maxLength: 6,
                    enableSuggestions: false,
                    autocorrect: false,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: widget.onChanged,
                    style: const TextStyle(color: Colors.transparent),
                    cursorColor: Colors.transparent,
                    decoration: InputDecoration(
                      labelText: widget.label,
                      counterText: '',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DriverOnlinePinStatus extends StatelessWidget {
  const DriverOnlinePinStatus({
    super.key,
    required this.isVerifying,
    required this.errorMessage,
  });

  final bool isVerifying;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    if (!isVerifying && errorMessage == null) {
      return const SizedBox.shrink();
    }

    final isError = errorMessage != null;
    final color = isError ? AppColors.error : AppColors.info;
    final icon = isError ? Icons.error_outline_rounded : Icons.sync_rounded;
    final message = errorMessage ?? 'Đang kiểm tra mã PIN...';

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppRadius.md,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodySmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
