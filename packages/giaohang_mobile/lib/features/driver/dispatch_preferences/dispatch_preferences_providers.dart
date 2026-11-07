import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dispatch_preferences.dart';

class DispatchPreferencesRepository {
  DispatchPreferencesRepository(this.client);
  final SupabaseClient client;
  Future<DispatchPreferences> load(
    String userId,
  ) async => DispatchPreferences.fromJson(
    await client
        .from('drivers')
        .select(
          'dispatch_mode,operating_area_id,destination_lat,destination_lng,destination_label,destination_expires_at,nearby_delivery_limit_m',
        )
        .eq('user_id', userId)
        .single(),
  );
  Future<List<OperatingArea>> areas() async {
    final rows = await client
        .from('driver_operating_areas')
        .select('id,province_code,province_name,name')
        .eq('enabled', true)
        .order('province_name')
        .order('name');
    return rows.map(OperatingArea.fromJson).toList();
  }

  Future<void> save(DispatchPreferences preferences) async {
    await client.rpc(
      'set_driver_dispatch_preferences',
      params: {
        'p_mode': preferences.mode.name,
        'p_area_id': preferences.areaId,
        'p_destination_lat': preferences.destination?.latitude,
        'p_destination_lng': preferences.destination?.longitude,
        'p_destination_label': preferences.destinationLabel,
        'p_nearby_delivery_limit_m': preferences.nearbyDeliveryLimitMeters,
      },
    );
  }
}

final dispatchPreferencesRepositoryProvider = Provider(
  (ref) => DispatchPreferencesRepository(Supabase.instance.client),
);
final dispatchPreferencesProvider = FutureProvider.autoDispose
    .family<DispatchPreferences, String>(
      (ref, id) => ref.watch(dispatchPreferencesRepositoryProvider).load(id),
    );
final operatingAreasProvider = FutureProvider<List<OperatingArea>>(
  (ref) => ref.watch(dispatchPreferencesRepositoryProvider).areas(),
);
