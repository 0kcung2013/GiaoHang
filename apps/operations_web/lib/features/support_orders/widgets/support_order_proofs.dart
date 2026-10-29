import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../data/support_order_repository.dart';
import '../dialogs/support_order_proof_dialog.dart';
import '../models/support_order_proof.dart';
import '../utils/support_order_proof_strings.dart';
import '../utils/support_order_ui.dart';
import 'support_order_information_components.dart';
import 'support_order_proof_image.dart';

class SupportOrderProofs extends StatefulWidget {
  const SupportOrderProofs({
    required this.orderId,
    required this.repository,
    super.key,
  });

  final String orderId;
  final SupportOrderRepository repository;

  @override
  State<SupportOrderProofs> createState() => _SupportOrderProofsState();
}

class _SupportOrderProofsState extends State<SupportOrderProofs> {
  late Future<List<SupportOrderProof>?> _proofs;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SupportOrderProofs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId ||
        oldWidget.repository != widget.repository) {
      _load();
    }
  }

  void _load() {
    _revision++;
    _proofs = _fetch();
  }

  Future<List<SupportOrderProof>?> _fetch() async {
    try {
      return await widget.repository.fetchDeliveryProofs(widget.orderId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => SupportOrderInfoSection(
    title: SupportOrderProofStrings.title,
    icon: Icons.photo_library_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(_load),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: AppColors.primary,
              textStyle: AppTextStyles.labelMedium,
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(SupportOrderProofStrings.refresh),
          ),
        ),
        FutureBuilder<List<SupportOrderProof>?>(
          future: _proofs,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.xl2),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accent,
                    semanticsLabel: SupportOrderProofStrings.loading,
                  ),
                ),
              );
            }
            if (snapshot.hasError || snapshot.data == null) {
              return Text(
                SupportOrderProofStrings.loadError,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              );
            }
            final proofs = {
              for (final proof in snapshot.data ?? <SupportOrderProof>[])
                proof.stage: proof,
            };
            return LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    constraints.maxWidth >= 560 &&
                    MediaQuery.textScalerOf(context).scale(1) < 1.4;
                final width = wide
                    ? (constraints.maxWidth - AppSpacing.lg) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.lg,
                  children: [
                    for (final stage in [
                      'pickup',
                      'delivery',
                      if (proofs.containsKey('return')) 'return',
                    ])
                      SizedBox(
                        width: width,
                        child: _ProofCard(
                          key: ValueKey('$stage:$_revision'),
                          stage: stage,
                          proof: proofs[stage],
                          repository: widget.repository,
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ],
    ),
  );
}

class _ProofCard extends StatelessWidget {
  const _ProofCard({
    required this.stage,
    required this.proof,
    required this.repository,
    super.key,
  });

  final String stage;
  final SupportOrderProof? proof;
  final SupportOrderRepository repository;

  @override
  Widget build(BuildContext context) {
    final photo = proof;
    final label = SupportOrderProofStrings.stageLabel(stage);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                stage == 'pickup'
                    ? Icons.inventory_2_outlined
                    : stage == 'delivery'
                    ? Icons.local_shipping_outlined
                    : Icons.assignment_return_outlined,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(label, style: AppTextStyles.labelMedium)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (photo == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl2),
              child: Text(
                SupportOrderProofStrings.notVisible,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: AppRadius.sm,
              child: SizedBox(
                height: 192,
                child: SupportOrderProofImage(
                  loadUrl: () =>
                      repository.resolveDeliveryProofUrl(photo.storagePath),
                  semanticLabel: label,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              SupportOrderUi.formatDateTime(photo.capturedAt),
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => showSupportOrderProofDialog(
                context,
                proof: photo,
                repository: repository,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: AppTextStyles.labelMedium,
                minimumSize: const Size(48, 48),
                side: const BorderSide(color: AppColors.border),
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.sm),
              ),
              icon: const Icon(Icons.zoom_in_rounded, size: 20),
              label: const Text(SupportOrderProofStrings.view),
            ),
          ],
        ],
      ),
    );
  }
}
