import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'profile_changes/data/admin_driver_media_resolver.dart';
import 'profile_changes/data/admin_driver_profile_change_repository.dart';
import 'profile_changes/widgets/admin_driver_profile_change_queue.dart';
import 'widgets/admin_driver_kyc_sheet.dart';
import 'widgets/admin_driver_registry_panel.dart';

class AdminDriversScreen extends StatefulWidget {
  const AdminDriversScreen({super.key});

  @override
  State<AdminDriversScreen> createState() => _AdminDriversScreenState();
}

class _AdminDriversScreenState extends State<AdminDriversScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _profileChangeRepository = SupabaseAdminDriverProfileChangeRepository();
  final _mediaResolver = SupabaseAdminDriverMediaResolver();

  late final TabController _tabController;
  List<DriverModel> _drivers = [];
  bool _loading = true;
  String? _error;
  RealtimeChannel? _driversChannel;
  int _pendingChangeCount = 0;

  static const _tabs = [
    {'label': 'Chờ duyệt', 'status': 'pending'},
    {'label': 'Đã duyệt', 'status': 'approved'},
    {'label': 'Từ chối', 'status': 'rejected'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length + 1, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index < _tabs.length) {
          _fetchDrivers();
        } else {
          setState(() {});
        }
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
    if (_tabController.index >= _tabs.length) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final status = _tabs[_tabController.index]['status']!;

      final response = await _supabase.rpc(
        'admin_list_drivers',
        params: {'p_status': status},
      );

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

  void _openKyc(DriverModel driver) {
    showAdminDriverKycSheet(
      context: context,
      driver: driver,
      onChanged: _fetchDrivers,
      mediaResolver: _mediaResolver,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isProfileChangesTab = _tabController.index == _tabs.length;
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
            tabs: [
              ..._tabs.map((tab) => Tab(text: tab['label']!)),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Yêu cầu thay đổi'),
                    if (_pendingChangeCount > 0) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: AppRadius.full,
                        ),
                        child: Text(
                          '$_pendingChangeCount',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textOnAccent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: isProfileChangesTab ? 1 : 0,
            children: [
              AdminDriverRegistryPanel(
                drivers: _drivers,
                loading: _loading,
                error: _error,
                onRetry: _fetchDrivers,
                onOpenDriver: _openKyc,
              ),
              AdminDriverProfileChangeQueue(
                repository: _profileChangeRepository,
                mediaResolver: _mediaResolver,
                onPendingCountChanged: (count) {
                  if (mounted && count != _pendingChangeCount) {
                    setState(() => _pendingChangeCount = count);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
