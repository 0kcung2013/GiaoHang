import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/models/driver_model.dart';

class AdminDriversScreen extends StatefulWidget {
  const AdminDriversScreen({super.key});

  @override
  State<AdminDriversScreen> createState() => _AdminDriversScreenState();
}

class _AdminDriversScreenState extends State<AdminDriversScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  late final TabController _tabController;
  List<DriverModel> _drivers = [];
  bool _loading = true;
  String? _error;
  RealtimeChannel? _driversChannel;

  static const _tabs = [
    {'label': 'Chờ duyệt', 'status': 'pending'},
    {'label': 'Đã duyệt', 'status': 'approved'},
    {'label': 'Từ chối', 'status': 'rejected'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _fetchDrivers();
      }
    });
    _fetchDrivers();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    _driversChannel = _supabase
        .channel('admin_drivers_watch')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'drivers',
          callback: (payload) {
            _fetchDrivers();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_driversChannel != null) {
      _supabase.removeChannel(_driversChannel!);
    }
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDrivers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final status = _tabs[_tabController.index]['status']!;

      final response = await _supabase.rpc('admin_list_drivers', params: {
        'p_status': status,
      });

      final drivers = (response as List<dynamic>).map((item) {
        return DriverModel.fromJson(item as Map<String, dynamic>);
      }).toList();

      if (mounted) setState(() => _drivers = drivers);
    } catch (e) {
      if (mounted) setState(() => _error = 'Không thể tải danh sách tài xế.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(String driverId) async {
    try {
      await _supabase.rpc('approve_driver', params: {'p_driver_id': driverId});
      _fetchDrivers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lỗi khi duyệt tài xế')));
      }
    }
  }

  Future<void> _reject(String driverId) async {
    try {
      await _supabase.rpc('reject_driver', params: {'p_driver_id': driverId});
      _fetchDrivers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lỗi khi từ chối tài xế')));
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Chờ duyệt';
      case 'approved':
        return 'Đã duyệt';
      case 'rejected':
        return 'Từ chối';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.bgCard,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: AppTextStyles.labelMedium,
            unselectedLabelStyle: AppTextStyles.labelMedium,
            tabs: _tabs.map((t) => Tab(text: t['label']!)).toList(),
          ),
        ),
        Expanded(
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                    child: Text(
                      _error!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                  : _drivers.isEmpty
                  ? Center(
                    child: Text(
                      'Không có tài xế nào',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.screenH),
                    itemCount: _drivers.length,
                    itemBuilder: (context, index) {
                      final driver = _drivers[index];
                      return _DriverCard(
                        driver: driver,
                        onApprove:
                            driver.approvalStatus == 'pending'
                                ? () => _approve(driver.id)
                                : null,
                        onReject:
                            driver.approvalStatus == 'pending'
                                ? () => _reject(driver.id)
                                : null,
                        statusColor: _statusColor(driver.approvalStatus),
                        statusLabel: _statusLabel(driver.approvalStatus),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}

class _DriverCard extends StatelessWidget {
  final DriverModel driver;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final Color statusColor;
  final String statusLabel;

  const _DriverCard({
    required this.driver,
    required this.onApprove,
    required this.onReject,
    required this.statusColor,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: AppRadius.sm,
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.fullName ?? 'Chưa có tên',
                      style: AppTextStyles.headingSmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      driver.email ?? '',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.full,
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusLabel,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(
            icon: Icons.phone_outlined,
            label: driver.phone ?? 'Chưa có SĐT',
          ),
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            icon: Icons.directions_car_outlined,
            label:
                '${driver.vehicleType ?? ''}  ·  ${driver.licensePlate ?? ''}',
          ),
          if (onApprove != null || onReject != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (onReject != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error.withValues(
                          alpha: 0.4,
                        )),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.sm,
                        ),
                      ),
                      child: const Text('Từ chối'),
                    ),
                  ),
                if (onReject != null && onApprove != null)
                  const SizedBox(width: AppSpacing.md),
                if (onApprove != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.sm,
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Duyệt'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
