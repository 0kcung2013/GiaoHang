import 'dart:async';

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../data/admin_driver_media_resolver.dart';
import '../data/admin_driver_profile_change_repository.dart';
import '../dialogs/admin_driver_profile_change_detail_sheet.dart';
import 'admin_driver_profile_change_card.dart';

class AdminDriverProfileChangeQueue extends StatefulWidget {
  const AdminDriverProfileChangeQueue({
    super.key,
    required this.repository,
    required this.mediaResolver,
    this.onPendingCountChanged,
  });

  final AdminDriverProfileChangeRepository repository;
  final AdminDriverMediaResolver mediaResolver;
  final ValueChanged<int>? onPendingCountChanged;

  @override
  State<AdminDriverProfileChangeQueue> createState() =>
      _AdminDriverProfileChangeQueueState();
}

class _AdminDriverProfileChangeQueueState
    extends State<AdminDriverProfileChangeQueue> {
  List<DriverProfileChangeRequest> _requests = const [];
  StreamSubscription<void>? _subscription;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _subscription = widget.repository.watchChanges().skip(1).listen((_) {
      _load(showLoading: false);
    });
  }

  @override
  void didUpdateWidget(covariant AdminDriverProfileChangeQueue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _subscription?.cancel();
      _subscription = widget.repository.watchChanges().skip(1).listen((_) {
        _load(showLoading: false);
      });
      _load();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final requests = await widget.repository.fetchPending();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _loading = false;
        _error = null;
      });
      widget.onPendingCountChanged?.call(requests.length);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không thể tải yêu cầu thay đổi hồ sơ.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.warning,
              size: 40,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _load,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(48, 48),
              ),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    if (_requests.isEmpty) return const _EmptyProfileChangeQueue();

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        itemCount: _requests.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final request = _requests[index];
          return AdminDriverProfileChangeCard(
            request: request,
            onTap: () => showAdminDriverProfileChangeDetailSheet(
              context: context,
              request: request,
              repository: widget.repository,
              mediaResolver: widget.mediaResolver,
              onChanged: () => _load(showLoading: false),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyProfileChangeQueue extends StatelessWidget {
  const _EmptyProfileChangeQueue();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(AppSpacing.xl2),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadow.subtle,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: AppRadius.lg,
              ),
              child: const Icon(
                Icons.task_alt_rounded,
                color: AppColors.accent,
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Không có yêu cầu đang chờ',
              textAlign: TextAlign.center,
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Yêu cầu mới từ tài xế sẽ xuất hiện tại đây để Admin xử lý.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
