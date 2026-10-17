import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/address_list_snapshot.dart';
import '../models/saved_address_model.dart';
import '../utils/geo_utils.dart';
import 'address_cache_service.dart';

class SavedAddressService {
  SavedAddressService({SupabaseClient? client, AddressCacheService? cache})
    : _supabase = client ?? Supabase.instance.client,
      _cache = cache ?? AddressCacheService();

  final SupabaseClient _supabase;
  final AddressCacheService _cache;

  static const String _table = 'saved_addresses';
  static const double duplicateRadiusMeters = 25;

  Future<AddressListSnapshot<SavedAddressModel>> loadSavedAddresses(
    String userId,
  ) async {
    try {
      final addresses = await _fetchRemote(userId);
      await _cache.writeSaved(userId, addresses);
      return AddressListSnapshot(items: addresses);
    } catch (error) {
      final cached = await _cache.readSaved(userId);
      if (cached != null) {
        return AddressListSnapshot(
          items: cached,
          isFromCache: true,
          warning:
              'Đang hiển thị địa chỉ đã lưu trên thiết bị. Một số thay đổi mới có thể chưa được cập nhật.',
        );
      }
      throw AddressBookException('Không tải được địa chỉ đã lưu.', error);
    }
  }

  Future<SavedAddressModel?> findNearby({
    required String userId,
    required double latitude,
    required double longitude,
    String? excludingId,
  }) async {
    const coordinateWindow = 0.00035;
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq('user_id', userId)
          .gte('latitude', latitude - coordinateWindow)
          .lte('latitude', latitude + coordinateWindow)
          .gte('longitude', longitude - coordinateWindow)
          .lte('longitude', longitude + coordinateWindow)
          .limit(12);

      for (final row in response) {
        final address = SavedAddressModel.fromJson(row);
        if (address.id == excludingId) continue;
        final distance = GeoUtils.distanceMeters(
          fromLat: latitude,
          fromLng: longitude,
          toLat: address.latitude,
          toLng: address.longitude,
        );
        if (distance <= duplicateRadiusMeters) return address;
      }
      return null;
    } catch (error) {
      throw AddressBookException('Không kiểm tra được địa chỉ trùng.', error);
    }
  }

  Future<SavedAddressModel> createSavedAddress(
    SavedAddressModel address,
  ) async {
    try {
      final currentDefault = await _supabase
          .from(_table)
          .select('id')
          .eq('user_id', address.userId)
          .eq('is_default', true)
          .limit(1);
      final shouldBecomeDefault = currentDefault.isEmpty;
      final payload = address.toMutationJson()
        ..['is_default'] = shouldBecomeDefault;

      final response = await _supabase
          .from(_table)
          .insert(payload)
          .select()
          .single();
      var created = SavedAddressModel.fromJson(response);

      if (address.isDefault && !created.isDefault) {
        await setDefault(created.id, address.userId);
        created = created.copyWith(isDefault: true);
      } else {
        await _refreshCache(address.userId);
      }
      return created;
    } catch (error) {
      throw AddressBookException('Không lưu được địa chỉ.', error);
    }
  }

  Future<SavedAddressModel> updateSavedAddress(
    SavedAddressModel address,
  ) async {
    try {
      final response = await _supabase
          .from(_table)
          .update(address.toMutationJson())
          .eq('id', address.id)
          .eq('user_id', address.userId)
          .select()
          .single();
      final updated = SavedAddressModel.fromJson(response);
      await _refreshCache(address.userId);
      return updated;
    } catch (error) {
      throw AddressBookException('Không cập nhật được địa chỉ.', error);
    }
  }

  Future<void> deleteSavedAddress(String addressId, String userId) async {
    try {
      await _supabase
          .from(_table)
          .delete()
          .eq('id', addressId)
          .eq('user_id', userId);
      await _refreshCache(userId);
    } catch (error) {
      throw AddressBookException('Không xóa được địa chỉ.', error);
    }
  }

  Future<void> setDefault(String addressId, String userId) async {
    try {
      await _supabase.rpc(
        'set_default_saved_address',
        params: {'p_address_id': addressId},
      );
      await _refreshCache(userId);
    } catch (error) {
      throw AddressBookException('Không đặt được địa chỉ mặc định.', error);
    }
  }

  Future<List<SavedAddressModel>> _fetchRemote(String userId) async {
    final response = await _supabase
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('is_default', ascending: false)
        .order('updated_at', ascending: false);
    return response.map(SavedAddressModel.fromJson).toList(growable: false);
  }

  Future<void> _refreshCache(String userId) async {
    try {
      await _cache.writeSaved(userId, await _fetchRemote(userId));
    } catch (_) {
      // Cache không được phép làm hỏng một mutation đã thành công trên server.
    }
  }
}

class AddressBookException implements Exception {
  const AddressBookException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
