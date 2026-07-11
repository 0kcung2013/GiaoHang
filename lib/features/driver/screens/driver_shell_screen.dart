import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/providers/customer_providers.dart';
import 'account/driver_account_screen.dart';
import 'earnings/driver_earnings_screen.dart';
import 'home/home_screen.dart';
import 'orders/driver_orders_screen.dart';
import 'widgets/driver_drawer.dart';

class DriverShellScreen extends ConsumerStatefulWidget {
  const DriverShellScreen({super.key});

  @override
  ConsumerState<DriverShellScreen> createState() => _DriverShellScreenState();
}

class _DriverShellScreenState extends ConsumerState<DriverShellScreen> {
  static const _tabs = [
    DriverHomeScreen(),
    DriverOrdersScreen(),
    DriverEarningsScreen(),
    DriverAccountScreen(),
  ];

  static const _titles = [
    'Tổng quan',
    'Đơn hàng',
    'Thu nhập',
    'Tài khoản',
  ];

  int _currentIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final cancelledId = ref.watch(latestCancelledOrderIdProvider);

    if (cancelledId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(latestCancelledOrderIdProvider.notifier).state = null;
        if (mounted) _showCancelledDialog(cancelledId);
      });
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          _titles[_currentIndex],
          style: AppTextStyles.headingMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: AppColors.bgCard,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      drawer: DriverDrawer(
        currentIndex: _currentIndex,
        onNavigate: (index) => setState(() => _currentIndex = index),
      ),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _currentIndex, children: _tabs),
      ),
    );
  }

  void _showCancelledDialog(String orderId) {
    final shortId =
        orderId.length >= 8 ? orderId.substring(0, 8) : orderId;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xl),
        contentPadding: const EdgeInsets.all(AppSpacing.xl2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cancel_rounded,
                color: AppColors.error,
                size: 30,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Đơn hàng đã bị huỷ',
              textAlign: TextAlign.center,
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Đơn #$shortId đã được khách hàng huỷ.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl2),
            SizedBox(
              width: double.infinity,
              child: Material(
                color: AppColors.info,
                borderRadius: AppRadius.full,
                child: InkWell(
                  onTap: () => Navigator.of(ctx).pop(),
                  borderRadius: AppRadius.full,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Center(
                      child: Text(
                        'Đã hiểu',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textOnAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
