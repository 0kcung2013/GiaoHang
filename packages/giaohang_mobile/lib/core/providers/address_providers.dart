import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/address_list_snapshot.dart';
import '../models/recent_address_model.dart';
import '../models/saved_address_model.dart';
import '../services/address_cache_service.dart';
import '../services/recent_address_service.dart';
import '../services/saved_address_service.dart';

final currentAddressUserIdProvider = Provider<String?>((ref) {
  return Supabase.instance.client.auth.currentUser?.id;
});

final addressCacheServiceProvider = Provider<AddressCacheService>((ref) {
  return AddressCacheService();
});

final savedAddressServiceProvider = Provider<SavedAddressService>((ref) {
  return SavedAddressService(cache: ref.watch(addressCacheServiceProvider));
});

final recentAddressServiceProvider = Provider<RecentAddressService>((ref) {
  return RecentAddressService(cache: ref.watch(addressCacheServiceProvider));
});

final savedAddressesProvider = FutureProvider.autoDispose
    .family<AddressListSnapshot<SavedAddressModel>, String>((ref, userId) {
      return ref.watch(savedAddressServiceProvider).loadSavedAddresses(userId);
    });

final recentAddressesProvider = FutureProvider.autoDispose
    .family<AddressListSnapshot<RecentAddressModel>, String>((ref, userId) {
      return ref
          .watch(recentAddressServiceProvider)
          .loadRecentAddresses(userId);
    });
