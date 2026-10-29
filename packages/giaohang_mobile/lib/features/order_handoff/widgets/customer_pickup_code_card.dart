import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../core/models/order_model.dart';
import '../data/pickup_handoff_service.dart';
import '../pickup_handoff_strings.dart';

class CustomerPickupCodeCard extends ConsumerStatefulWidget {
  const CustomerPickupCodeCard({super.key, required this.order});
  final OrderModel order;

  static bool isRelevant(OrderModel order) =>
      order.driverId != null &&
      (const {'assigned', 'picking_up'}.contains(order.status) ||
          order.actualPickedUpAt != null);

  @override
  ConsumerState<CustomerPickupCodeCard> createState() =>
      _CustomerPickupCodeCardState();
}

class _CustomerPickupCodeCardState extends ConsumerState<CustomerPickupCodeCard>
    with WidgetsBindingObserver {
  PickupHandoffCode? _result;
  Timer? _expiryTimer;
  bool _loading = false;
  String? _error;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant CustomerPickupCodeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id ||
        oldWidget.order.driverId != widget.order.driverId ||
        oldWidget.order.status != widget.order.status ||
        oldWidget.order.actualPickedUpAt != widget.order.actualPickedUpAt) {
      _clearCode();
    }
  }

  void _clearCode() {
    _requestVersion++;
    _expiryTimer?.cancel();
    _result = null;
    _error = null;
    _loading = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted) setState(_clearCode);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _reveal() async {
    final version = ++_requestVersion;
    final elapsed = Stopwatch()..start();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(pickupHandoffServiceProvider)
          .getCustomerCode(widget.order.id);
      if (!mounted || version != _requestVersion) return;
      if (result.confirmedAt == null &&
          result.driverId != widget.order.driverId) {
        throw const PickupHandoffException(PickupHandoffStrings.unavailable);
      }
      final remaining = result.expiresAt == null
          ? null
          : result.expiresAt!.difference(result.serverNow) - elapsed.elapsed;
      if (result.confirmedAt == null &&
          (remaining == null || remaining <= Duration.zero)) {
        throw const PickupHandoffException(PickupHandoffStrings.expired);
      }
      setState(() => _result = result);
      _expiryTimer?.cancel();
      if (remaining != null) {
        _expiryTimer = Timer(remaining, () {
          if (!mounted) return;
          setState(() {
            _result = null;
            _error = PickupHandoffStrings.expired;
          });
        });
      }
    } catch (error) {
      if (!mounted || version != _requestVersion) return;
      setState(
        () => _error = error is PickupHandoffException
            ? error.message
            : PickupHandoffStrings.loadFailure,
      );
    } finally {
      if (mounted && version == _requestVersion) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirmedAt = widget.order.actualPickedUpAt ?? _result?.confirmedAt;
    final confirmed = confirmedAt != null;
    final code = _result?.code;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                confirmed ? Icons.verified_rounded : Icons.lock_outline_rounded,
                color: confirmed ? AppColors.success : AppColors.accent,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  confirmed
                      ? PickupHandoffStrings.confirmed
                      : PickupHandoffStrings.title,
                  style: AppTextStyles.headingSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            confirmed
                ? PickupHandoffStrings.receipt
                : PickupHandoffStrings.notice,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          if (confirmedAt != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              MaterialLocalizations.of(
                context,
              ).formatTimeOfDay(TimeOfDay.fromDateTime(confirmedAt.toLocal())),
              style: AppTextStyles.labelMedium,
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              label: PickupHandoffStrings.codeLabel,
              child: Text(
                code ?? '••••',
                textAlign: TextAlign.center,
                style: AppTextStyles.displayLarge.copyWith(letterSpacing: 12),
              ),
            ),
            if (_result?.expiresAt != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                PickupHandoffStrings.validUntil(
                  MaterialLocalizations.of(context).formatTimeOfDay(
                    TimeOfDay.fromDateTime(_result!.expiresAt!.toLocal()),
                  ),
                ),
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
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
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: _loading
                  ? null
                  : code == null
                  ? _reveal
                  : () => setState(_clearCode),
              icon: Icon(
                code == null
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
              ),
              label: Text(
                _loading
                    ? PickupHandoffStrings.loading
                    : code == null
                    ? PickupHandoffStrings.reveal
                    : PickupHandoffStrings.hide,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textOnAccent,
                minimumSize: const Size.fromHeight(52),
                textStyle: AppTextStyles.labelMedium,
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
