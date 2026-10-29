import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class BusinessSettingsRepository {
  Future<BusinessSettings> load();
  Future<BusinessSettings> save(BusinessSettings settings, String reason);
  Future<List<SettingsRevision>> history({int? beforeRevision});
}

class SettingsRevision {
  SettingsRevision.fromJson(Map<String, dynamic> json)
    : settings = BusinessSettings.fromJson(json),
      previousValues = json['previous_values'] is Map
          ? Map<String, dynamic>.from(json['previous_values'] as Map)
          : null,
      reason = json['reason'] as String,
      actor =
          json['actor_name'] as String? ??
          json['updated_by'] as String? ??
          'Hệ thống',
      at = DateTime.parse(json['updated_at'] as String);

  final BusinessSettings settings;
  final Map<String, dynamic>? previousValues;
  final String reason, actor;
  final DateTime at;
}

class SupabaseBusinessSettingsRepository implements BusinessSettingsRepository {
  SupabaseBusinessSettingsRepository(this.client);
  final SupabaseClient client;

  @override
  Future<BusinessSettings> load() async => BusinessSettings.fromJson(
    Map<String, dynamic>.from(await client.rpc('get_business_settings') as Map),
  );

  @override
  Future<BusinessSettings> save(
    BusinessSettings settings,
    String reason,
  ) async => BusinessSettings.fromJson(
    Map<String, dynamic>.from(
      await client.rpc(
            'update_business_settings',
            params: {
              'p_values': settings.values,
              'p_expected_revision': settings.revision,
              'p_reason': reason.trim(),
            },
          )
          as Map,
    ),
  );

  @override
  Future<List<SettingsRevision>> history({int? beforeRevision}) async =>
      (await client.rpc(
                'get_business_settings_history',
                params: {'p_before_revision': beforeRevision, 'p_limit': 20},
              )
              as List)
          .map(
            (row) => SettingsRevision.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
}
