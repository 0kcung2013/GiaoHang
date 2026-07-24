import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/review_model.dart';
import '../../../core/providers/customer_providers.dart';

/// Sheet tài xế đánh giá khách sau khi giao xong.
Future<bool?> showDriverRateCustomerSheet({
  required BuildContext context,
  required OrderModel order,
  String? customerName,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _DriverRateCustomerSheet(
      order: order,
      customerName: customerName,
    ),
  );
}

class _DriverRateCustomerSheet extends ConsumerStatefulWidget {
  const _DriverRateCustomerSheet({
    required this.order,
    this.customerName,
  });

  final OrderModel order;
  final String? customerName;

  @override
  ConsumerState<_DriverRateCustomerSheet> createState() =>
      _DriverRateCustomerSheetState();
}

class _DriverRateCustomerSheetState
    extends ConsumerState<_DriverRateCustomerSheet> {
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
      await ref.read(reviewServiceProvider).submitDriverCustomerReview(
            orderId: widget.order.id,
            rating: _rating,
            comment: _commentCtrl.text.trim().isEmpty
                ? null
                : _commentCtrl.text.trim(),
            tags: _selectedTags.toList(),
          );
      ref.invalidate(driverCustomerReviewProvider(widget.order.id));
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi đánh giá khách hàng'),
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
    final name = (widget.customerName?.trim().isNotEmpty ?? false)
        ? widget.customerName!.trim()
        : 'Khách hàng';

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
              'Đánh giá khách hàng',
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
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Đánh giá giúp cải thiện an toàn cộng đồng tài xế',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
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
                for (final tag in driverCustomerReviewTags)
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
                    selectedColor: AppColors.info.withValues(alpha: 0.15),
                    checkmarkColor: AppColors.info,
                    labelStyle: AppTextStyles.labelSmall.copyWith(
                      color: _selectedTags.contains(tag.id)
                          ? AppColors.info
                          : AppColors.textSecondary,
                    ),
                    side: BorderSide(
                      color: _selectedTags.contains(tag.id)
                          ? AppColors.info.withValues(alpha: 0.4)
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
                hintText: 'Ghi chú nội bộ (không bắt buộc)',
                border: OutlineInputBorder(borderRadius: AppRadius.md),
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
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(false),
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
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
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
