import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

class DriverMapStartControl extends StatelessWidget {
  const DriverMapStartControl({
    required this.running,
    required this.onStart,
    this.onStop,
    super.key,
  });

  static const startLabel = 'Start';
  static const runningLabel = 'Stop';

  final bool running;
  final VoidCallback? onStart;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: running ? 'Dừng di chuyển' : 'Bắt đầu di chuyển',
    child: FilledButton.icon(
      key: const ValueKey('driver-map-start'),
      onPressed: running ? onStop : onStart,
      icon: Icon(
        running ? Icons.pause_rounded : Icons.play_arrow_rounded,
        size: 20,
      ),
      label: Text(
        running ? runningLabel : startLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: FilledButton.styleFrom(
        textStyle: AppTextStyles.labelMedium,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnDark,
        disabledBackgroundColor: AppColors.bgCard,
        disabledForegroundColor: AppColors.textSecondary,
        minimumSize: const Size(88, 48),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.full),
      ),
    ),
  );
}
