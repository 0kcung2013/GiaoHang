import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/models/user_model.dart';
import '../../../../../core/providers/customer_providers.dart';
import '../utils/vietnam_phone_input.dart';

class SenderContactSection extends ConsumerStatefulWidget {
  const SenderContactSection({super.key});

  @override
  ConsumerState<SenderContactSection> createState() =>
      _SenderContactSectionState();
}

class _SenderContactSectionState extends ConsumerState<SenderContactSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) {
      return const _SenderNotice(
        icon: Icons.lock_outline_rounded,
        message: 'Đăng nhập để sử dụng thông tin người gửi.',
      );
    }

    final profileAsync = ref.watch(customerProfileProvider(authUser.id));
    return profileAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => _SenderNotice(
        icon: Icons.refresh_rounded,
        message: 'Không tải được thông tin người gửi. Chạm để thử lại.',
        onTap: () => ref.invalidate(customerProfileProvider(authUser.id)),
      ),
      data: (profile) {
        final details = _SenderData.from(profile, authUser);
        return Semantics(
          container: true,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: AppRadius.xl,
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadow.subtle,
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: AppRadius.lg,
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: AppColors.accentLight,
                            borderRadius: AppRadius.md,
                          ),
                          child: const Icon(
                            Icons.account_circle_outlined,
                            color: AppColors.accent,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Người gửi',
                                style: AppTextStyles.headingSmall.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                details.isComplete
                                    ? '${details.name} · Thông tin từ tài khoản'
                                    : 'Cần cập nhật thông tin tài khoản',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: details.isComplete
                                      ? AppColors.textSecondary
                                      : AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.accentLight,
                            borderRadius: AppRadius.full,
                          ),
                          child: Text(
                            '05',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          _expanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedCrossFade(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : AppDuration.normal,
                  crossFadeState: _expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: _SenderDetails(details: details),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SenderData {
  const _SenderData({
    required this.name,
    required this.phone,
    required this.email,
    required this.isComplete,
  });

  factory _SenderData.from(UserModel? profile, User authUser) {
    final profileName = profile?.fullName.trim() ?? '';
    final profilePhone = profile?.phone?.trim() ?? '';
    final name = profileName.isNotEmpty
        ? profileName
        : authUser.userMetadata?['full_name']?.toString().trim() ?? '';
    final phone = normalizeVietnamPhone(
      profilePhone.isNotEmpty ? profilePhone : authUser.phone ?? '',
    );
    final email = (profile?.email.trim().isNotEmpty ?? false)
        ? profile!.email.trim()
        : authUser.email ?? '';
    return _SenderData(
      name: name,
      phone: phone,
      email: email,
      isComplete: name.isNotEmpty && isValidVietnamPhone(phone),
    );
  }

  final String name;
  final String phone;
  final String email;
  final bool isComplete;
}

class _SenderDetails extends StatelessWidget {
  const _SenderDetails({required this.details});

  final _SenderData details;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.lg,
        border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          _DetailLine(
            Icons.person_outline_rounded,
            details.name.isEmpty ? 'Chưa có họ tên' : details.name,
          ),
          const SizedBox(height: AppSpacing.md),
          _DetailLine(
            Icons.phone_outlined,
            details.phone.isEmpty ? 'Chưa có số điện thoại' : details.phone,
          ),
          if (details.email.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _DetailLine(Icons.mail_outline_rounded, details.email),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            details.isComplete
                ? 'Thông tin này được lấy từ tài khoản của bạn.'
                : 'Cập nhật họ tên và số điện thoại trong Tài khoản trước khi đặt đơn.',
            style: AppTextStyles.bodySmall.copyWith(
              color: details.isComplete
                  ? AppColors.textSecondary
                  : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.icon, this.value);

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _SenderNotice extends StatelessWidget {
  const _SenderNotice({required this.icon, required this.message, this.onTap});

  final IconData icon;
  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.xl,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadow.subtle,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: AppRadius.md,
              ),
              child: Icon(icon, color: AppColors.warning, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
