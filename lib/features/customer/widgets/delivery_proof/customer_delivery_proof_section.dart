import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/delivery_proof_model.dart';
import '../../../../core/providers/customer_providers.dart';
import 'customer_delivery_proof_viewer.dart';

class CustomerDeliveryProofSection extends ConsumerStatefulWidget {
  const CustomerDeliveryProofSection({
    super.key,
    required this.orderId,
    required this.orderStatus,
    this.imageBuilder = buildCustomerProofNetworkImage,
    this.pollInterval = const Duration(seconds: 5),
  });

  final String orderId;
  final String orderStatus;
  final CustomerProofImageBuilder imageBuilder;
  final Duration pollInterval;

  @override
  ConsumerState<CustomerDeliveryProofSection> createState() =>
      _CustomerDeliveryProofSectionState();
}

class _CustomerDeliveryProofSectionState
    extends ConsumerState<CustomerDeliveryProofSection> {
  static const _visibleStatuses = {'picking_up', 'delivering', 'delivered'};

  Timer? _pollTimer;

  @override
  void didUpdateWidget(covariant CustomerDeliveryProofSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId ||
        oldWidget.orderStatus != widget.orderStatus) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visibleStatuses.contains(widget.orderStatus)) {
      _queuePollingSync(shouldPoll: false);
      return const SizedBox.shrink();
    }

    final asyncProofs = ref.watch(orderDeliveryProofsProvider(widget.orderId));
    final proofs = asyncProofs.valueOrNull ?? const <DeliveryProofImageModel>[];
    final expectedCount = switch (widget.orderStatus) {
      'picking_up' || 'delivering' => 1,
      'delivered' => 2,
      _ => 0,
    };
    _queuePollingSync(
      shouldPoll:
          !asyncProofs.isLoading &&
          !asyncProofs.hasError &&
          proofs.length < expectedCount,
    );

    if (asyncProofs.hasError && proofs.isEmpty) {
      return _ProofErrorCard(
        onRetry: () {
          ref.invalidate(orderDeliveryProofsProvider(widget.orderId));
        },
      );
    }

    return _ProofGalleryCard(
      proofs: proofs,
      orderStatus: widget.orderStatus,
      isLoading: asyncProofs.isLoading && proofs.isEmpty,
      imageBuilder: widget.imageBuilder,
    );
  }

  void _queuePollingSync({required bool shouldPoll}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!shouldPoll) {
        _pollTimer?.cancel();
        _pollTimer = null;
        return;
      }
      if (_pollTimer?.isActive == true) return;
      _pollTimer = Timer(widget.pollInterval, () {
        _pollTimer = null;
        if (!mounted) return;
        ref.invalidate(orderDeliveryProofsProvider(widget.orderId));
      });
    });
  }
}

class _ProofGalleryCard extends StatelessWidget {
  const _ProofGalleryCard({
    required this.proofs,
    required this.orderStatus,
    required this.isLoading,
    required this.imageBuilder,
  });

  final List<DeliveryProofImageModel> proofs;
  final String orderStatus;
  final bool isLoading;
  final CustomerProofImageBuilder imageBuilder;

  @override
  Widget build(BuildContext context) {
    final pickup = _proofFor(DeliveryProofStage.pickup);
    final delivery = _proofFor(DeliveryProofStage.delivery);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: AppRadius.md,
                ),
                child: const Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.accent,
                  size: 23,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ảnh bàn giao',
                      style: AppTextStyles.headingSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Ảnh do tài xế chụp tại hai mốc bàn giao.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ProofTile(
                  title: 'Ảnh nhận hàng',
                  emptyLabel: isLoading ? 'Đang tải...' : 'Đang chờ ảnh',
                  proof: pickup,
                  accent: AppColors.markerPickup,
                  imageBuilder: imageBuilder,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _ProofTile(
                  title: 'Ảnh giao hàng',
                  emptyLabel: isLoading
                      ? 'Đang tải...'
                      : orderStatus == 'delivered'
                      ? 'Chưa có ảnh'
                      : 'Sau khi giao',
                  proof: delivery,
                  accent: AppColors.markerDrop,
                  imageBuilder: imageBuilder,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  DeliveryProofImageModel? _proofFor(DeliveryProofStage stage) {
    for (final image in proofs) {
      if (image.proof.stage == stage) return image;
    }
    return null;
  }
}

class _ProofTile extends StatelessWidget {
  const _ProofTile({
    required this.title,
    required this.emptyLabel,
    required this.proof,
    required this.accent,
    required this.imageBuilder,
  });

  final String title;
  final String emptyLabel;
  final DeliveryProofImageModel? proof;
  final Color accent;
  final CustomerProofImageBuilder imageBuilder;

  @override
  Widget build(BuildContext context) {
    final image = proof;
    final semanticLabel = image == null ? '$title chưa có' : 'Xem $title';

    return Semantics(
      button: image != null,
      label: semanticLabel,
      child: Material(
        color: AppColors.bgLight,
        borderRadius: AppRadius.md,
        child: InkWell(
          onTap: image == null
              ? null
              : () => showCustomerDeliveryProofViewer(
                  context: context,
                  image: image,
                  title: title,
                  imageBuilder: imageBuilder,
                ),
          borderRadius: AppRadius.md,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: AppRadius.md,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ClipRRect(
                    borderRadius: AppRadius.sm,
                    child: image == null
                        ? _ProofPlaceholder(accent: accent)
                        : imageBuilder(
                            context,
                            image.imageUrl,
                            title,
                            BoxFit.cover,
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  image == null
                      ? emptyLabel
                      : formatDeliveryProofCapturedAt(image.proof.capturedAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: image == null
                        ? AppColors.textMuted
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProofPlaceholder extends StatelessWidget {
  const _ProofPlaceholder({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: accent.withValues(alpha: 0.09),
      child: Center(
        child: Icon(
          Icons.add_a_photo_outlined,
          color: accent.withValues(alpha: 0.72),
          size: 30,
        ),
      ),
    );
  }
}

class _ProofErrorCard extends StatelessWidget {
  const _ProofErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.image_not_supported_rounded, color: AppColors.error),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Không tải được ảnh bàn giao.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}
