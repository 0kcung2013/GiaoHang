import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../data/admin_driver_media_resolver.dart';
import '../data/admin_driver_profile_change_repository.dart';
import '../widgets/admin_driver_profile_change_diff.dart';

Future<void> showAdminDriverProfileChangeDetailSheet({
  required BuildContext context,
  required DriverProfileChangeRequest request,
  required AdminDriverProfileChangeRepository repository,
  required AdminDriverMediaResolver mediaResolver,
  required VoidCallback onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.bgLight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.92,
      child: _AdminDriverProfileChangeDetailSheet(
        request: request,
        repository: repository,
        mediaResolver: mediaResolver,
        onChanged: onChanged,
      ),
    ),
  );
}

class _AdminDriverProfileChangeDetailSheet extends StatefulWidget {
  const _AdminDriverProfileChangeDetailSheet({
    required this.request,
    required this.repository,
    required this.mediaResolver,
    required this.onChanged,
  });

  final DriverProfileChangeRequest request;
  final AdminDriverProfileChangeRepository repository;
  final AdminDriverMediaResolver mediaResolver;
  final VoidCallback onChanged;

  @override
  State<_AdminDriverProfileChangeDetailSheet> createState() =>
      _AdminDriverProfileChangeDetailSheetState();
}

class _AdminDriverProfileChangeDetailSheetState
    extends State<_AdminDriverProfileChangeDetailSheet> {
  final _reasonController = TextEditingController();
  bool _showRejection = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.request.currentSnapshot ?? const {};
    final name = snapshot['full_name']?.toString().trim();
    return Column(
      children: [
        _DetailHeader(
          name: name?.isNotEmpty == true ? name! : 'Hồ sơ tài xế',
          onClose: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RequestReason(reason: widget.request.reason),
                  const SizedBox(height: AppSpacing.xl),
                  AdminDriverProfileChangeDiff(
                    request: widget.request,
                    mediaResolver: widget.mediaResolver,
                  ),
                ],
              ),
            ),
          ),
        ),
        _DecisionFooter(
          showRejection: _showRejection,
          busy: _busy,
          error: _error,
          reasonController: _reasonController,
          onStartRejection: () => setState(() {
            _showRejection = true;
            _error = null;
          }),
          onCancelRejection: () => setState(() {
            _showRejection = false;
            _error = null;
          }),
          onApprove: _approve,
          onReject: _reject,
        ),
      ],
    );
  }

  Future<void> _approve() async {
    final count = buildDriverProfileDiff(widget.request).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
        title: const Text('Duyệt toàn bộ yêu cầu?'),
        content: Text(
          '$count thay đổi sẽ được áp dụng cùng lúc. Hành động này không duyệt từng trường riêng lẻ.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Kiểm tra lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.textOnAccent,
            ),
            child: const Text('Duyệt toàn bộ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runDecision(() => widget.repository.approve(widget.request));
  }

  Future<void> _reject() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Vui lòng nhập lý do từ chối');
      return;
    }
    await _runDecision(
      () => widget.repository.reject(widget.request.id, reason),
    );
  }

  Future<void> _runDecision(Future<void> Function() command) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await command();
      widget.onChanged();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object error) => error is AdminDriverProfileChangeException
      ? error.message
      : 'Chưa thể xử lý yêu cầu. Vui lòng thử lại.';
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.name, required this.onClose});

  final String name;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: AppRadius.md,
            ),
            child: const Icon(
              Icons.admin_panel_settings_outlined,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.headingMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Yêu cầu thay đổi hồ sơ · Chỉ Admin được quyết định',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            tooltip: 'Đóng',
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _RequestReason extends StatelessWidget {
  const _RequestReason({required this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: AppRadius.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notes_rounded, color: AppColors.accent, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Lý do của tài xế: ${reason?.trim().isNotEmpty == true ? reason!.trim() : 'Không cung cấp'}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionFooter extends StatelessWidget {
  const _DecisionFooter({
    required this.showRejection,
    required this.busy,
    required this.error,
    required this.reasonController,
    required this.onStartRejection,
    required this.onCancelRejection,
    required this.onApprove,
    required this.onReject,
  });

  final bool showRejection;
  final bool busy;
  final String? error;
  final TextEditingController reasonController;
  final VoidCallback onStartRejection;
  final VoidCallback onCancelRejection;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showRejection) ...[
            TextField(
              key: const Key('profile-rejection-reason'),
              controller: reasonController,
              minLines: 1,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Lý do từ chối',
                hintText: 'Nêu rõ thông tin cần tài xế bổ sung',
                border: OutlineInputBorder(borderRadius: AppRadius.md),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (error != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                error!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy
                      ? null
                      : showRejection
                      ? onCancelRejection
                      : onStartRejection,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    minimumSize: const Size(48, 52),
                    side: const BorderSide(color: AppColors.error),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.full,
                    ),
                  ),
                  child: Text(showRejection ? 'Quay lại' : 'Từ chối'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  key: showRejection
                      ? const Key('confirm-profile-rejection')
                      : null,
                  onPressed: busy
                      ? null
                      : showRejection
                      ? onReject
                      : onApprove,
                  style: FilledButton.styleFrom(
                    backgroundColor: showRejection
                        ? AppColors.error
                        : AppColors.success,
                    foregroundColor: AppColors.textOnAccent,
                    minimumSize: const Size(48, 52),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.full,
                    ),
                  ),
                  child: Text(
                    busy
                        ? 'Đang xử lý...'
                        : showRejection
                        ? 'Xác nhận từ chối'
                        : 'Duyệt toàn bộ',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
