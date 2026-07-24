import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/review_model.dart';
import '../../../core/providers/customer_providers.dart';

/// Mở sheet đánh giá tài xế (khách → TX) sau khi giao xong.
Future<bool?> showSubmitReviewSheet({
  required BuildContext context,
  required OrderModel order,
  String? driverName,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SubmitReviewSheet(
      order: order,
      driverName: driverName,
    ),
  );
}

class _SubmitReviewSheet extends ConsumerStatefulWidget {
  const _SubmitReviewSheet({
    required this.order,
    this.driverName,
  });

  final OrderModel order;
  final String? driverName;

  @override
  ConsumerState<_SubmitReviewSheet> createState() => _SubmitReviewSheetState();
}

class _SubmitReviewSheetState extends ConsumerState<_SubmitReviewSheet> {
  int _rating = 0;
  final _commentCtrl = TextEditingController();
  final Set<String> _selectedTags = {};
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating < 1) {
      setState(() => _error = 'Vui lòng chọn số sao');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(reviewServiceProvider).submitCustomerDriverReview(
            orderId: widget.order.id,
            rating: _rating,
            comment: _commentCtrl.text.trim().isEmpty
                ? null
                : _commentCtrl.text.trim(),
            tags: _selectedTags.toList(),
          );
      ref.invalidate(orderReviewProvider(widget.order.id));
      ref.invalidate(assignedDriverProvider(widget.order.id));
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cảm ơn bạn đã đánh giá!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final name = (widget.driverName?.trim().isNotEmpty ?? false)
        ? widget.driverName!.trim()
        : 'Tài xế giao hàng';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl + bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: AppRadius.full,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Đánh giá tài xế',
              style: AppTextStyles.headingMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              name,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.order.trackingCode.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.order.trackingCode,
                style: AppTextStyles.mono.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                final filled = star <= _rating;
                return IconButton(
                  onPressed: _submitting
                      ? null
                      : () => setState(() {
                            _rating = star;
                            _error = null;
                          }),
                  iconSize: 36,
                  icon: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: filled ? AppColors.warning : AppColors.textMuted,
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                for (final tag in customerDriverReviewTags)
                  FilterChip(
                    label: Text(tag.label),
                    selected: _selectedTags.contains(tag.id),
                    onSelected: _submitting
                        ? null
                        : (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTags.add(tag.id);
                              } else {
                                _selectedTags.remove(tag.id);
                              }
                            });
                          },
                    selectedColor: AppColors.accentLight,
                    checkmarkColor: AppColors.accent,
                    labelStyle: AppTextStyles.labelSmall.copyWith(
                      color: _selectedTags.contains(tag.id)
                          ? AppColors.accent
                          : AppColors.textSecondary,
                    ),
                    side: BorderSide(
                      color: _selectedTags.contains(tag.id)
                          ? AppColors.accent.withValues(alpha: 0.4)
                          : AppColors.border,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _commentCtrl,
              enabled: !_submitting,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Nhận xét (không bắt buộc)',
                border: OutlineInputBorder(borderRadius: AppRadius.md),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.md,
                  borderSide: const BorderSide(color: AppColors.borderFocus),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _submitting ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Bỏ qua'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _submitting || _rating < 1 ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.textOnAccent,
                      minimumSize: const Size.fromHeight(48),
                      elevation: 0,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Gửi đánh giá'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
