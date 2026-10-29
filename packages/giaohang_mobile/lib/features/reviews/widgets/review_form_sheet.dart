import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../core/models/order_model.dart';
import '../../../core/models/review_model.dart';
import '../../../core/providers/customer_providers.dart';
import '../../../core/services/review_service.dart';
import '../review_strings.dart';
import 'review_choices.dart';

class ReviewFormSheet extends ConsumerStatefulWidget {
  const ReviewFormSheet({
    super.key,
    required this.order,
    required this.direction,
    this.recipientName,
  });
  final OrderModel order;
  final String direction;
  final String? recipientName;

  @override
  ConsumerState<ReviewFormSheet> createState() => _ReviewFormSheetState();
}

class _ReviewFormSheetState extends ConsumerState<ReviewFormSheet> {
  final _comment = TextEditingController();
  final _tags = <String>{};
  int _rating = 0;
  bool _submitting = false;
  String? _error;
  bool get _toDriver => widget.direction == ReviewDirection.customerToDriver;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || _rating < 1) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final service = ref.read(reviewServiceProvider);
      final receipt = await (_toDriver
          ? service.submitCustomerDriverReview(
              orderId: widget.order.id,
              rating: _rating,
              comment: _comment.text,
              tags: _tags.toList(),
            )
          : service.submitDriverCustomerReview(
              orderId: widget.order.id,
              rating: _rating,
              comment: _comment.text,
              tags: _tags.toList(),
            ));
      if (!mounted) return;
      if (_toDriver) {
        ref.invalidate(orderReviewProvider(widget.order.id));
        ref.invalidate(assignedDriverProvider(widget.order.id));
      } else {
        ref.invalidate(driverCustomerReviewProvider(widget.order.id));
      }
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            receipt['already_reviewed'] == true
                ? ReviewStrings.alreadyRecorded
                : ReviewStrings.success,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error is ReviewException
            ? error.message
            : ReviewService.submitError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.recipientName?.trim();
    return PopScope(
      canPop: !_submitting,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _toDriver
                  ? ReviewStrings.driverTitle
                  : ReviewStrings.customerTitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.headingMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              name?.isNotEmpty == true
                  ? name!
                  : (_toDriver ? ReviewStrings.driver : ReviewStrings.customer),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (widget.order.trackingCode.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.order.trackingCode,
                textAlign: TextAlign.center,
                style: AppTextStyles.mono.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            ReviewChoices(
              rating: _rating,
              tags: _tags,
              enabled: !_submitting,
              options: _toDriver
                  ? customerDriverReviewTags
                  : driverCustomerReviewTags,
              onRating: (value) => setState(() {
                _rating = value;
                _error = null;
              }),
              onTag: (id, selected) => setState(() {
                selected ? _tags.add(id) : _tags.remove(id);
              }),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _comment,
              enabled: !_submitting,
              minLines: 2,
              maxLines: 4,
              maxLength: ReviewService.maxCommentLength,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                labelText: ReviewStrings.comment,
                helperText: ReviewStrings.optional,
                alignLabelWithHint: true,
                filled: true,
                fillColor: AppColors.bgLight,
                border: OutlineInputBorder(borderRadius: AppRadius.md),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.md,
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.md,
                  borderSide: const BorderSide(color: AppColors.borderFocus),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _submitting || _rating == 0 ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textOnAccent,
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.all(AppSpacing.md),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
              ),
              child: _submitting
                  ? Semantics(
                      label: ReviewStrings.submitting,
                      liveRegion: true,
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textOnAccent,
                        ),
                      ),
                    )
                  : const Text(ReviewStrings.submit),
            ),
            TextButton(
              onPressed: _submitting
                  ? null
                  : () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text(ReviewStrings.skip),
            ),
          ],
        ),
      ),
    );
  }
}
