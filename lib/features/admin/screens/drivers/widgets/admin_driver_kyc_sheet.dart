import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/models/driver_model.dart';

/// Bottom sheet admin xem KYC + duyệt / từ chối kèm lý do.
Future<void> showAdminDriverKycSheet({
  required BuildContext context,
  required DriverModel driver,
  required VoidCallback onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AdminDriverKycSheet(driver: driver, onChanged: onChanged),
  );
}

class _AdminDriverKycSheet extends StatefulWidget {
  const _AdminDriverKycSheet({
    required this.driver,
    required this.onChanged,
  });

  final DriverModel driver;
  final VoidCallback onChanged;

  @override
  State<_AdminDriverKycSheet> createState() => _AdminDriverKycSheetState();
}

class _AdminDriverKycSheetState extends State<_AdminDriverKycSheet> {
  final _reasonCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc(
        'approve_driver',
        params: {'p_driver_id': widget.driver.id},
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã duyệt tài xế')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi khi duyệt tài xế')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập lý do từ chối')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc(
        'reject_driver',
        params: {
          'p_driver_id': widget.driver.id,
          'p_reason': reason,
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã từ chối hồ sơ')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi khi từ chối tài xế')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.driver;
    final isPending = d.approvalStatus == 'pending';
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl + bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
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
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: (d.avatarUrl != null &&
                          d.avatarUrl!.trim().isNotEmpty)
                      ? NetworkImage(d.avatarUrl!)
                      : null,
                  child: (d.avatarUrl == null || d.avatarUrl!.trim().isEmpty)
                      ? const Icon(Icons.person, color: AppColors.primary)
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.fullName ?? 'Chưa có tên',
                        style: AppTextStyles.headingSmall,
                      ),
                      Text(
                        d.email ?? '',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        d.phone ?? '',
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
            Text('Phương tiện', style: AppTextStyles.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              [
                d.vehicleType,
                d.vehicleBrandModel,
                d.vehicleColor,
                d.licensePlate,
              ].where((e) => e != null && e.trim().isNotEmpty).join(' · '),
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Giấy tờ KYC', style: AppTextStyles.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            _InfoLine(label: 'CCCD', value: d.idCardNumber),
            _InfoLine(label: 'GPLX', value: d.driverLicenseNumber),
            if (d.rejectionReason != null &&
                d.rejectionReason!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: AppRadius.md,
                ),
                child: Text(
                  'Lý do từ chối: ${d.rejectionReason}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _KycImageThumb(label: 'CCCD trước', url: d.idCardFrontUrl),
                _KycImageThumb(label: 'CCCD sau', url: d.idCardBackUrl),
                _KycImageThumb(label: 'GPLX', url: d.driverLicenseUrl),
                _KycImageThumb(label: 'Ảnh xe', url: d.vehiclePhotoUrl),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _reasonCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Lý do từ chối (bắt buộc nếu từ chối)',
                  border: OutlineInputBorder(borderRadius: AppRadius.md),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : _reject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Từ chối'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _busy ? null : _approve,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        elevation: 0,
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Duyệt'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, this.value});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label: ${value == null || value!.trim().isEmpty ? '—' : value}',
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _KycImageThumb extends StatelessWidget {
  const _KycImageThumb({required this.label, this.url});
  final String label;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.trim().isNotEmpty;
    return InkWell(
      onTap: !hasUrl
          ? null
          : () {
              showDialog<void>(
                context: context,
                builder: (ctx) => Dialog(
                  child: InteractiveViewer(
                    child: Image.network(url!, fit: BoxFit.contain),
                  ),
                ),
              );
            },
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: AppColors.bgLight,
          borderRadius: AppRadius.sm,
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasUrl
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(url!, fit: BoxFit.cover),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      color: Colors.black54,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: Text(
                  'Chưa có\n$label',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
      ),
    );
  }
}
