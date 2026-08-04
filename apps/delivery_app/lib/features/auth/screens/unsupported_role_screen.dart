import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/auth_service.dart';

class UnsupportedRoleScreen extends StatelessWidget {
  const UnsupportedRoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 52, color: AppColors.error),
              const SizedBox(height: AppSpacing.lg),
              Text('Vai trò không hợp lệ', style: AppTextStyles.headingMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tài khoản này không có quyền sử dụng Delivery App.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.tonal(
                onPressed: () async {
                  await AuthService().signOut();
                  if (context.mounted) context.go('/login');
                },
                child: const Text('Đăng xuất'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
