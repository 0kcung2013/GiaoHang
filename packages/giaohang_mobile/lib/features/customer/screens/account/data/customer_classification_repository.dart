import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/models/user_model.dart';

final customerClassificationRepositoryProvider =
    Provider<CustomerClassificationRepository>(
      (ref) =>
          SupabaseCustomerClassificationRepository(Supabase.instance.client),
    );

abstract interface class CustomerClassificationRepository {
  Future<UserModel> save({
    required String userId,
    required String type,
    String? businessName,
    String? businessAddress,
    String? taxCode,
  });
}

class SupabaseCustomerClassificationRepository
    implements CustomerClassificationRepository {
  SupabaseCustomerClassificationRepository(this.client);
  final SupabaseClient client;

  @override
  Future<UserModel> save({
    required String userId,
    required String type,
    String? businessName,
    String? businessAddress,
    String? taxCode,
  }) async {
    final id = client.auth.currentUser?.id;
    if (id == null || id != userId) throw const AuthException('AUTH_REQUIRED');
    if (type != 'individual' && type != 'business') {
      throw const FormatException('CUSTOMER_TYPE_INVALID');
    }
    final business = type == 'business';
    final row = await client
        .from('users')
        .update({
          'customer_type': type,
          'business_name': business ? businessName?.trim() : null,
          'business_address': business ? businessAddress?.trim() : null,
          'business_tax_code': business && (taxCode?.trim().isNotEmpty ?? false)
              ? taxCode!.trim()
              : null,
        })
        .eq('id', id)
        .eq('role', 'customer')
        .select()
        .single()
        .timeout(const Duration(seconds: 15));
    return UserModel.fromJson(row);
  }
}
