import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/constants/app_theme.dart';
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
              border: Border(
                top: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
              ),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_circle_outlined, size: 22),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Người gửi',
                                style: AppTextStyles.headingSmall.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
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
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textSecondary,
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
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
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
        color: Color(0xFFF4F5F7),
        borderRadius: AppRadius.lg,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Row(
          children: [
            Icon(icon, color: AppColors.warning),
            const SizedBox(width: AppSpacing.sm),
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
