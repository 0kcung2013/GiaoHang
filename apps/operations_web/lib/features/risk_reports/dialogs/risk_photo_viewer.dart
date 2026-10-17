import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../constants/risk_journey_strings.dart';

/// Ảnh đã được cấp URL theo quyền của hồ sơ đang mở.
class RiskPhotoViewer extends StatefulWidget {
  const RiskPhotoViewer({
    required this.urls,
    required this.initialIndex,
    super.key,
  });
  final List<String> urls;
  final int initialIndex;

  @override
  State<RiskPhotoViewer> createState() => _RiskPhotoViewerState();
}

class _RiskPhotoViewerState extends State<RiskPhotoViewer> {
  late int index = widget.initialIndex;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppColors.bgDark,
    insetPadding: const EdgeInsets.all(AppSpacing.lg),
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
    child: SizedBox(
      width: 1100,
      height: MediaQuery.sizeOf(context).height * .85,
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  RiskJourneyStrings.photoTitle(index + 1, widget.urls.length),
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textOnDark,
                  ),
                ),
              ),
              IconButton(
                tooltip: RiskJourneyStrings.close,
                color: AppColors.textOnDark,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Expanded(
            child: InteractiveViewer(
              key: ValueKey(index),
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: Image.network(
                  widget.urls[index],
                  fit: BoxFit.contain,
                  semanticLabel: RiskJourneyStrings.photoLabel(index + 1),
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accent,
                          ),
                        ),
                  errorBuilder: (_, _, _) => Text(
                    RiskJourneyStrings.photoError,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textOnDark,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: RiskJourneyStrings.previousPhoto,
                color: AppColors.textOnDark,
                onPressed: index > 0 ? () => setState(() => index--) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  RiskJourneyStrings.zoomHint,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textOnDark,
                  ),
                ),
              ),
              IconButton(
                tooltip: RiskJourneyStrings.nextPhoto,
                color: AppColors.textOnDark,
                onPressed: index < widget.urls.length - 1
                    ? () => setState(() => index++)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
