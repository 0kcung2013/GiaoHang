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
          callback: (payload) {
            _load();
          },
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

      final drivers = await _supabase.rpc('admin_list_drivers', params: {
        'p_status': 'pending',
      }) as List<dynamic>;
      _pendingDrivers = drivers.map((d) => DriverModel.fromJson(d as Map<String, dynamic>)).toList();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screenH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tổng quan',
              style: AppTextStyles.headingLarge.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Hôm nay, cập nhật theo thời gian thực',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl2),
            _StatGrid(stats: _stats, loading: _loading),
            const SizedBox(height: AppSpacing.xl2),
            Text(
              'Tài xế chờ duyệt',
              style: AppTextStyles.headingSmall.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (_pendingDrivers.isEmpty)
              _EmptyCard(
                icon: Icons.check_circle_outline,
                message: 'Không có tài xế nào đang chờ duyệt',
              )
            else
              ..._pendingDrivers.take(3).map((d) => _PendingDriverTile(driver: d)),
            const SizedBox(height: AppSpacing.xl4),
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
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.5,
      children: [
        _StatCard(icon: Icons.inventory_2_rounded, label: 'Tổng đơn', value: stats?['total_orders'], color: AppColors.primary, loading: loading),
        _StatCard(icon: Icons.hourglass_empty_rounded, label: 'Chờ xử lý', value: stats?['pending_orders'], color: AppColors.warning, loading: loading),
        _StatCard(icon: Icons.local_shipping_rounded, label: 'Đang giao', value: stats?['delivering_orders'], color: AppColors.info, loading: loading),
        _StatCard(icon: Icons.payments_outlined, label: 'Doanh thu', value: stats?['total_revenue'] != null ? '${(stats!['total_revenue'] as num).toStringAsFixed(0)}đ' : null, color: AppColors.success, loading: loading),
        _StatCard(icon: Icons.people_alt_rounded, label: 'Tài xế', value: stats?['total_drivers'], color: AppColors.accent, loading: loading),
        _StatCard(icon: Icons.person_rounded, label: 'Khách hàng', value: stats?['total_customers'], color: const Color(0xFF8B5CF6), loading: loading),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final dynamic value;
  final Color color;
  final bool loading;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: AppRadius.sm),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              if (loading)
                SizedBox(width: 32, height: 4, child: Container(decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: AppRadius.full))),
            ],
          ),
          if (loading)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Container(width: 48, height: 24, decoration: BoxDecoration(color: AppColors.border, borderRadius: AppRadius.xs)),
            )
          else
            Text(value?.toString() ?? '0', style: AppTextStyles.displayMedium.copyWith(color: AppColors.textPrimary)),
          Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
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
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: AppRadius.sm),
            child: const Icon(Icons.person_outline, color: AppColors.warning, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(driver.fullName ?? 'Chưa có tên', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              Text(driver.email ?? '', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            ]),
          ),
          Text(driver.vehicleType ?? '', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
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
      padding: const EdgeInsets.all(AppSpacing.xl3),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 40),
          const SizedBox(height: AppSpacing.md),
          Text(message, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
