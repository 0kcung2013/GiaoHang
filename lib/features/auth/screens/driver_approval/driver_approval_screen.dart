import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_theme.dart';

class DriverApprovalScreen extends StatefulWidget {
  const DriverApprovalScreen({super.key});

  @override
  State<DriverApprovalScreen> createState() => _DriverApprovalScreenState();
}

class _DriverApprovalScreenState extends State<DriverApprovalScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  String _approvalStatus = 'pending';

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    try {
      final result = await _supabase
          .from('drivers')
          .select('approval_status')
          .eq('user_id', user.id)
          .single();

      final status = result['approval_status'] as String? ?? 'pending';

      if (mounted) {
        if (status == 'approved') {
          context.go('/driver-home');
        } else {
          setState(() {
            _approvalStatus = status;
            _loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _logout() async {
    await _supabase.auth.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bgLight,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isPending = _approvalStatus == 'pending';

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(AppSpacing.xl3),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: AppRadius.xl,
                boxShadow: AppShadow.card,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: (isPending ? AppColors.warning : AppColors.error)
                          .withValues(alpha: 0.1),
                      borderRadius: AppRadius.lg,
                    ),
                    child: Icon(
                      isPending
                          ? Icons.hourglass_empty_rounded
                          : Icons.block_rounded,
                      size: 40,
                      color:
                          isPending ? AppColors.warning : AppColors.error,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl2),
                  Text(
                    isPending
                        ? 'Hồ sơ đang chờ duyệt'
                        : 'Hồ sơ bị từ chối',
                    style: AppTextStyles.headingMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    isPending
                        ? 'Admin sẽ xem xét và duyệt hồ sơ của bạn trong thời gian sớm nhất. Vui lòng quay lại sau.'
                        : 'Hồ sơ tài xế của bạn chưa được duyệt. Vui lòng liên hệ admin để biết thêm chi tiết.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl3),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _fetchStatus,
                      icon: const Icon(Icons.refresh, size: 20),
                      label: const Text('Kiểm tra lại'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.md,
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: _logout,
                    child: Text(
                      'Đăng xuất',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
