import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/driver_model.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _stats;
  List<DriverModel> _pendingDrivers = [];
  bool _loading = true;
  RealtimeChannel? _driversChannel;

  @override
  void initState() {
    super.initState();
    _load();
    _driversChannel = _supabase
        .channel('admin_dashboard_drivers_watch')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'drivers',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_driversChannel != null) {
      _supabase.removeChannel(_driversChannel!);
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final stats = await _supabase.rpc('admin_dashboard_stats');
      _stats = stats is Map<String, dynamic> ? stats : {};

      final drivers = await _supabase.rpc(
        'admin_list_drivers',
        params: {'p_status': 'pending'},
      ) as List<dynamic>;
      _pendingDrivers = drivers
          .map((d) => DriverModel.fromJson(d as Map<String, dynamic>))
          .toList();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.lg,
          AppSpacing.screenH,
          AppSpacing.xl4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Xin chào, Quản trị viên',
              style: AppTextStyles.headingLarge.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Cập nhật theo thời gian thực',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _StatGrid(stats: _stats, loading: _loading),
            const SizedBox(height: AppSpacing.xl2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tài xế chờ duyệt',
                    style: AppTextStyles.headingSmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (_pendingDrivers.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: AppRadius.full,
                    ),
                    child: Text(
                      '${_pendingDrivers.length}',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_pendingDrivers.isEmpty)
              const _EmptyCard(
                icon: Icons.check_circle_outline,
                message: 'Không có tài xế nào đang chờ duyệt',
              )
            else
              ..._pendingDrivers.take(5).map(
                    (d) => _PendingDriverTile(driver: d),
                  ),
          ],
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final Map<String, dynamic>? stats;
  final bool loading;

  const _StatGrid({required this.stats, required this.loading});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 720 ? 3 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          // Cao hơn một chút để tránh overflow chữ lớn
          childAspectRatio: 1.65,
          children: [
            _StatCard(
              icon: Icons.inventory_2_rounded,
              label: 'Tổng đơn',
              value: stats?['total_orders'],
              color: AppColors.primary,
              loading: loading,
            ),
            _StatCard(
              icon: Icons.hourglass_empty_rounded,
              label: 'Chờ xử lý',
              value: stats?['pending_orders'],
              color: AppColors.warning,
              loading: loading,
            ),
            _StatCard(
              icon: Icons.local_shipping_rounded,
              label: 'Đang giao',
              value: stats?['delivering_orders'],
              color: AppColors.info,
              loading: loading,
            ),
            _StatCard(
              icon: Icons.payments_outlined,
              label: 'Doanh thu',
              value: stats?['total_revenue'] != null
                  ? '${(stats!['total_revenue'] as num).toStringAsFixed(0)}đ'
                  : null,
              color: AppColors.success,
              loading: loading,
            ),
            _StatCard(
              icon: Icons.people_alt_rounded,
              label: 'Tài xế',
              value: stats?['total_drivers'],
              color: AppColors.accent,
              loading: loading,
            ),
            _StatCard(
              icon: Icons.person_rounded,
              label: 'Khách hàng',
              value: stats?['total_customers'],
              color: const Color(0xFF8B5CF6),
              loading: loading,
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final dynamic value;
  final Color color;
  final bool loading;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.sm,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          if (loading)
            Container(
              width: 40,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: AppRadius.xs,
              ),
            )
          else
            Text(
              value?.toString() ?? '0',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.headingLarge.copyWith(
                color: AppColors.textPrimary,
                fontSize: 22,
                height: 1.15,
              ),
            ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingDriverTile extends StatelessWidget {
  final DriverModel driver;
  const _PendingDriverTile({required this.driver});

  @override
  Widget build(BuildContext context) {
    final vehicle = [
      driver.vehicleType,
      driver.licensePlate,
    ].where((e) => e != null && e.trim().isNotEmpty).join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.warning.withValues(alpha: 0.12),
            backgroundImage:
                (driver.avatarUrl != null && driver.avatarUrl!.trim().isNotEmpty)
                    ? NetworkImage(driver.avatarUrl!)
                    : null,
            child: (driver.avatarUrl == null ||
                    driver.avatarUrl!.trim().isEmpty)
                ? const Icon(
                    Icons.person_outline,
                    color: AppColors.warning,
                    size: 20,
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver.fullName ?? 'Chưa có tên',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  driver.email ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (vehicle.isNotEmpty)
            Flexible(
              child: Text(
                vehicle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl2),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.success, size: 36),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
