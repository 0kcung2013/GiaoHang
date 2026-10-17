import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../../../../core/models/delivery_proof_model.dart';

typedef CustomerProofImageBuilder =
    Widget Function(
      BuildContext context,
      String imageUrl,
      String semanticLabel,
      BoxFit fit,
    );

Widget buildCustomerProofNetworkImage(
  BuildContext context,
  String imageUrl,
  String semanticLabel,
  BoxFit fit,
) {
  return Image.network(
    imageUrl,
    fit: fit,
    width: double.infinity,
    height: double.infinity,
    semanticLabel: semanticLabel,
    cacheWidth: fit == BoxFit.cover ? 720 : null,
    loadingBuilder: (context, child, progress) {
      if (progress == null) return child;
      return const _ProofImageState(icon: Icons.image_rounded);
    },
    errorBuilder: (_, _, _) {
      return const _ProofImageState(icon: Icons.broken_image_rounded);
    },
  );
}

Future<void> showCustomerDeliveryProofViewer({
  required BuildContext context,
  required DeliveryProofImageModel image,
  required String title,
  CustomerProofImageBuilder imageBuilder = buildCustomerProofNetworkImage,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Đóng ảnh bàn giao',
    barrierColor: AppColors.primary.withValues(alpha: 0.92),
    transitionDuration: AppDuration.normal,
    transitionBuilder: (context, animation, _, child) {
      return FadeTransition(opacity: animation, child: child);
    },
    pageBuilder: (context, _, _) {
      return Material(
        color: AppColors.primary,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTextStyles.headingSmall.copyWith(
                              color: AppColors.textOnDark,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            formatDeliveryProofCapturedAt(
                              image.proof.capturedAt,
                            ),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textOnDark.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Đóng',
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textOnDark,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Center(
                    child: imageBuilder(
                      context,
                      image.imageUrl,
                      title,
                      BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

String formatDeliveryProofCapturedAt(DateTime value) {
  final local = VietnamTime.toWallClock(value);
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(local.hour)}:${twoDigits(local.minute)} · '
      '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year}';
}

class _ProofImageState extends StatelessWidget {
  const _ProofImageState({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bgDarkCard,
      child: Center(
        child: Icon(
          icon,
          color: AppColors.textOnDark.withValues(alpha: 0.72),
          size: 36,
        ),
      ),
    );
  }
}
