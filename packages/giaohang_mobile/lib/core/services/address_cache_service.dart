import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/recent_address_model.dart';
import '../models/saved_address_model.dart';

class AddressCacheService {
  AddressCacheService({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferences;

  static const _savedPrefix = 'address_book.saved.v1';
  static const _recentPrefix = 'address_book.recent.v1';

  Future<List<SavedAddressModel>?> readSaved(String userId) {
    return _readList(_key(_savedPrefix, userId), SavedAddressModel.fromJson);
  }

  Future<void> writeSaved(String userId, List<SavedAddressModel> addresses) {
    return _writeList(
      _key(_savedPrefix, userId),
      addresses.map((address) => address.toJson()).toList(),
    );
  }

  Future<List<RecentAddressModel>?> readRecent(String userId) {
    return _readList(_key(_recentPrefix, userId), RecentAddressModel.fromJson);
  }

  Future<void> writeRecent(String userId, List<RecentAddressModel> addresses) {
    return _writeList(
      _key(_recentPrefix, userId),
      addresses.map((address) => address.toJson()).toList(),
    );
  }

  Future<List<T>?> _readList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final preferences = await _preferences();
    if (!preferences.containsKey(key)) return null;

    final encoded = preferences.getString(key);
    if (encoded == null || encoded.isEmpty) return <T>[];

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map>()
          .map((item) => fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } on FormatException {
      return null;
    }
  }

  Future<void> _writeList(String key, List<Map<String, dynamic>> items) async {
    final preferences = await _preferences();
    await preferences.setString(key, jsonEncode(items));
  }

  String _key(String prefix, String userId) => '$prefix.$userId';
}
