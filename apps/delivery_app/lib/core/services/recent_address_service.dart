import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/address_list_snapshot.dart';
import '../models/recent_address_model.dart';
import 'address_cache_service.dart';
import 'saved_address_service.dart';

class RecentAddressService {
  RecentAddressService({SupabaseClient? client, AddressCacheService? cache})
    : _supabase = client ?? Supabase.instance.client,
      _cache = cache ?? AddressCacheService();

  final SupabaseClient _supabase;
  final AddressCacheService _cache;

  static const String _table = 'recent_addresses';

  Future<AddressListSnapshot<RecentAddressModel>> loadRecentAddresses(
    String userId,
  ) async {
    try {
      final addresses = await _fetchRemote(userId);
      await _cache.writeRecent(userId, addresses);
      return AddressListSnapshot(items: addresses);
    } catch (error) {
      final cached = await _cache.readRecent(userId);
      if (cached != null) {
        return AddressListSnapshot(
          items: cached,
          isFromCache: true,
          warning:
              'Đang hiển thị lịch sử trên thiết bị. Bản đồ hoặc tìm kiếm có thể chưa khả dụng.',
        );
      }
      throw AddressBookException('Không tải được địa chỉ gần đây.', error);
    }
  }

  Future<void> recordOrderAddresses({
    required String userId,
    required RecentAddressModel pickup,
    required RecentAddressModel delivery,
  }) async {
    try {
      await _supabase.rpc(
        'record_recent_addresses',
        params: {
          'p_addresses': [pickup.toRecordJson(), delivery.toRecordJson()],
        },
      );
      await _refreshCache(userId);
    } catch (error) {
      throw AddressBookException(
        'Đơn đã tạo nhưng chưa cập nhật được địa chỉ gần đây.',
        error,
      );
    }
  }

  Future<void> deleteRecentAddress(String addressId, String userId) async {
    try {
      await _supabase
          .from(_table)
          .delete()
          .eq('id', addressId)
          .eq('user_id', userId);
      await _refreshCache(userId);
    } catch (error) {
      throw AddressBookException('Không xóa được địa chỉ gần đây.', error);
    }
  }

  Future<void> clearHistory(String userId) async {
    try {
      await _supabase.from(_table).delete().eq('user_id', userId);
      await _cache.writeRecent(userId, const []);
    } catch (error) {
      throw AddressBookException('Không xóa được lịch sử địa chỉ.', error);
    }
  }

  Future<List<RecentAddressModel>> _fetchRemote(String userId) async {
    final response = await _supabase
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('last_used_at', ascending: false)
        .limit(15);
    return response.map(RecentAddressModel.fromJson).toList(growable: false);
  }

  Future<void> _refreshCache(String userId) async {
    try {
      await _cache.writeRecent(userId, await _fetchRemote(userId));
    } catch (_) {
      // Cache không được phép làm hỏng một mutation đã thành công trên server.
    }
  }
}
