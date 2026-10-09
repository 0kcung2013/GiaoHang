import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../data/driver_cancellation_repository.dart';
import '../driver_cancellation_strings.dart';
import '../models/driver_cancellation_policy.dart';
import '../widgets/driver_cancellation_reason_card.dart';
import '../widgets/driver_deadline_countdown.dart';

Future<bool?> showDriverCancelOrderSheet({
  required BuildContext context,
  required DriverCancellationPolicy policy,
  required Future<void> Function(DriverCancellationReason) onConfirm,
  DateTime Function() now = DateTime.now,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  isDismissible: false,
  enableDrag: false,
  backgroundColor: AppColors.bgCard,
  constraints: const BoxConstraints(maxWidth: 560),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  clipBehavior: Clip.antiAlias,
  builder: (_) =>
      DriverCancelOrderSheet(policy: policy, onConfirm: onConfirm, now: now),
);

/// Callback chỉ hoàn tất sau khi server chấp nhận hủy/nhả đơn.
class DriverCancelOrderSheet extends StatefulWidget {
  const DriverCancelOrderSheet({
    super.key,
    required this.policy,
    required this.onConfirm,
    this.now = DateTime.now,
  });

  final DriverCancellationPolicy policy;
  final Future<void> Function(DriverCancellationReason) onConfirm;
  final DateTime Function() now;

  @override
  State<DriverCancelOrderSheet> createState() => _SheetState();
}

class _SheetState extends State<DriverCancelOrderSheet> {
  DriverCancellationReason? _reason;
  bool _submitting = false;
  String? _error;
  final _warningKey = GlobalKey();

  void _select(DriverCancellationReason reason) {
    if (_submitting || !widget.policy.allows(reason, widget.now())) return;
    setState(() {
      _reason = reason;
      _error = null;
    });
    if (reason == DriverCancellationReason.personal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final warningContext = _warningKey.currentContext;
        if (!mounted || warningContext == null) return;
        Scrollable.ensureVisible(
          warningContext,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : AppDuration.fast,
        );
      });
    }
  }

  Future<void> _confirm() async {
    final reason = _reason;
    if (_submitting ||
        reason == null ||
        !widget.policy.allows(reason, widget.now())) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onConfirm(reason);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is DriverCancellationException
              ? error.message
              : DriverCancellationStrings.failed,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled =
        !_submitting &&
        _reason != null &&
        widget.policy.allows(_reason!, widget.now());
    return PopScope(
      canPop: !_submitting,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: AppSpacing.xl4,
                          height: AppSpacing.xs,
                          decoration: const BoxDecoration(
                            color: AppColors.border,
                            borderRadius: AppRadius.full,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl2),
                      Row(
                        children: [
                          Container(
                            width: AppSpacing.xl5,
                            height: AppSpacing.xl5,
                            decoration: const BoxDecoration(
                              color: AppColors.accentLight,
                              borderRadius: AppRadius.lg,
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: AppColors.accent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DriverCancellationStrings.title,
                                  style: AppTextStyles.headingLarge.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  DriverCancellationStrings.chooseReason,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl2),
                      _storeOption(),
                      const SizedBox(height: AppSpacing.md),
                      DriverCancellationReasonCard(
                        title: DriverCancellationStrings.personal,
                        subtitle: DriverCancellationStrings.personalHint,
                        icon: Icons.person_outline_rounded,
                        selected: _reason == DriverCancellationReason.personal,
                        available: widget.policy.canCancel,
                        onPressed: _submitting
                            ? null
                            : () => _select(DriverCancellationReason.personal),
                      ),
                      if (!widget.policy.canCancel) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _notice(DriverCancellationStrings.unavailable),
                      ] else if (_reason ==
                          DriverCancellationReason.personal) ...[
                        const SizedBox(height: AppSpacing.lg),
                        KeyedSubtree(
                          key: _warningKey,
                          child: _notice(
                            DriverCancellationStrings.personalWarning,
                            detail: DriverCancellationStrings.redispatchHint,
                            icon: Icons.timer_outlined,
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Semantics(
                          liveRegion: true,
                          child: _notice(_error!, error: true),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl2),
                    ],
                  ),
                ),
              ),
              _actions(enabled),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actions(bool enabled) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.bgCard,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: enabled ? _confirm : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              padding: const EdgeInsets.all(AppSpacing.lg),
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textOnAccent,
              disabledBackgroundColor: AppColors.bgLight,
              disabledForegroundColor: AppColors.textSecondary,
              textStyle: AppTextStyles.labelLarge,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
            ),
            child: Text(
              _submitting
                  ? DriverCancellationStrings.submitting
                  : DriverCancellationStrings.confirm,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _submitting
                ? null
                : () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: AppColors.textPrimary,
              textStyle: AppTextStyles.labelLarge,
            ),
            child: const Text(DriverCancellationStrings.keepOrder),
          ),
        ],
      ),
    ),
  );

  Widget _storeOption() {
    final deadline = widget.policy.storeEligibleAt;
    if (deadline == null) return _storeCard();
    return DriverDeadlineCountdown(
      deadline: deadline,
      totalDuration: DriverCancellationPolicy.storeWait,
      now: widget.now,
      onExpired: () {
        if (mounted) setState(() {});
      },
      builder: (_, remaining) => _storeCard(remaining: remaining),
    );
  }

  Widget _storeCard({Duration? remaining}) {
    final ready = widget.policy.allows(
      DriverCancellationReason.storeClosed,
      widget.now(),
    );
    return DriverCancellationReasonCard(
      title: DriverCancellationStrings.storeClosed,
      subtitle: widget.policy.storeEligibleAt == null
          ? DriverCancellationStrings.arrivalRequired
          : ready
          ? DriverCancellationStrings.storeReadyHint
          : DriverCancellationStrings.storeWaitingHint,
      icon: Icons.storefront_rounded,
      selected: _reason == DriverCancellationReason.storeClosed,
      available: ready,
      onPressed: _submitting
          ? null
          : () => _select(DriverCancellationReason.storeClosed),
      status: !ready && remaining != null
          ? Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.border.withValues(alpha: 0.5),
                borderRadius: AppRadius.sm,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      DriverCancellationStrings.opensAfter(
                        DriverCancellationPolicy.formatRemaining(remaining),
                      ),
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _notice(
    String message, {
    String? detail,
    bool error = false,
    IconData icon = Icons.info_outline_rounded,
  }) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: (error ? AppColors.error : AppColors.warning).withValues(
        alpha: 0.08,
      ),
      borderRadius: AppRadius.md,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          error ? Icons.error_outline_rounded : icon,
          size: 22,
          color: error ? AppColors.error : AppColors.textPrimary,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  detail,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
