import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/saved_address_model.dart';

class SavedAddressService {
  SavedAddressService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const String _table = 'saved_addresses';

  Future<List<SavedAddressModel>> getSavedAddresses(String userId) async {
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq('user_id', userId)
          .order('is_default_pickup', ascending: false)
          .order('is_default_delivery', ascending: false)
          .order('updated_at', ascending: false);

      return response.map(SavedAddressModel.fromJson).toList();
    } catch (error) {
      throw Exception('Failed to load saved addresses: $error');
    }
  }

  Future<String> createSavedAddress(SavedAddressModel address) async {
    try {
      final payload = Map<String, dynamic>.from(address.toJson());
      _removeEmptyGeneratedId(payload);

      final response = await _supabase
          .from(_table)
          .insert(payload)
          .select('id')
          .single();

      final addressId = response['id']?.toString();
      if (addressId == null || addressId.isEmpty) {
        throw Exception('Created address did not return an id.');
      }

      return addressId;
    } catch (error) {
      throw Exception('Failed to create saved address: $error');
    }
  }

  Future<void> updateSavedAddress(SavedAddressModel address) async {
    try {
      await _supabase
          .from(_table)
          .update({
            'label': address.label,
            'contact_name': address.contactName,
            'contact_phone': address.contactPhone,
            'address_line': address.addressLine,
            'lat': address.lat,
            'lng': address.lng,
            'is_default_pickup': address.isDefaultPickup,
            'is_default_delivery': address.isDefaultDelivery,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', address.id)
          .eq('user_id', address.userId);
    } catch (error) {
      throw Exception('Failed to update saved address: $error');
    }
  }

  Future<void> deleteSavedAddress(String addressId, String userId) async {
    try {
      await _supabase
          .from(_table)
          .delete()
          .eq('id', addressId)
          .eq('user_id', userId);
    } catch (error) {
      throw Exception('Failed to delete saved address: $error');
    }
  }

  Future<void> setDefaultPickup(String addressId, String userId) async {
    try {
      await _supabase
          .from(_table)
          .update({
            'is_default_pickup': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('is_default_pickup', true);

      await _supabase
          .from(_table)
          .update({
            'is_default_pickup': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', addressId)
          .eq('user_id', userId);
    } catch (error) {
      throw Exception('Failed to set default pickup address: $error');
    }
  }

  Future<void> setDefaultDelivery(String addressId, String userId) async {
    try {
      await _supabase
          .from(_table)
          .update({
            'is_default_delivery': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('is_default_delivery', true);

      await _supabase
          .from(_table)
          .update({
            'is_default_delivery': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', addressId)
          .eq('user_id', userId);
    } catch (error) {
      throw Exception('Failed to set default delivery address: $error');
    }
  }

  void _removeEmptyGeneratedId(Map<String, dynamic> json) {
    if ((json['id'] as String?)?.isEmpty ?? true) {
      json.remove('id');
    }
  }
}