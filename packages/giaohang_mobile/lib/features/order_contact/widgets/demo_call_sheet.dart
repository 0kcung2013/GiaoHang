import 'dart:async';

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

Future<void> showDemoCallSheet({
  required BuildContext context,
  required String contactLabel,
  required String contactName,
  required String phone,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _DemoCallSheet(
      contactLabel: contactLabel,
      contactName: contactName,
      phone: phone,
    ),
  );
}

class _DemoCallSheet extends StatefulWidget {
  const _DemoCallSheet({
    required this.contactLabel,
    required this.contactName,
    required this.phone,
  });

  final String contactLabel;
  final String contactName;
  final String phone;

  @override
  State<_DemoCallSheet> createState() => _DemoCallSheetState();
}

class _DemoCallSheetState extends State<_DemoCallSheet> {
  Timer? _connectTimer;
  Timer? _durationTimer;
  bool _connected = false;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _connectTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() => _connected = true);
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsedSeconds++);
      });
    });
  }

  @override
  void dispose() {
    _connectTimer?.cancel();
    _durationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl2,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.18),
              borderRadius: AppRadius.full,
            ),
            child: Text(
              'CHẾ ĐỘ TRÌNH DIỄN',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl2),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.success,
              size: 38,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            widget.contactName,
            textAlign: TextAlign.center,
            style: AppTextStyles.headingLarge.copyWith(
              color: AppColors.textOnDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${widget.contactLabel} • ${widget.phone}',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textOnDark.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedSwitcher(
            duration: AppDuration.normal,
            child: Text(
              _connected ? '$minutes:$seconds' : 'Đang kết nối...',
              key: ValueKey(_connected),
              style: AppTextStyles.labelLarge.copyWith(
                color: _connected ? AppColors.success : AppColors.textOnDark,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl2),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.call_end_rounded),
              label: const Text('Kết thúc'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.textOnAccent,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.full),
                textStyle: AppTextStyles.labelLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
