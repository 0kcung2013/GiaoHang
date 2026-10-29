import 'package:giaohang_storage/giaohang_storage.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/models/user_model.dart';
import '../constants/customer_account_strings.dart';
import '../utils/customer_profile_validation.dart';

abstract interface class CustomerAccountRepository {
  Future<UserModel> load();
  Future<UserModel> save({
    required String userId,
    required String fullName,
    required String phone,
    String? avatarUrl,
  });
  Future<String> uploadAvatar(XFile file);
}

class SupabaseCustomerAccountRepository implements CustomerAccountRepository {
  SupabaseCustomerAccountRepository(this.client, {R2MediaClient? media})
    : _media = media ?? R2MediaClient.supabase(client: client);

  final SupabaseClient client;
  final R2MediaClient _media;
  String get _userId {
    final id = client.auth.currentUser?.id;
    if (id == null) throw const AuthException(CustomerAccountStrings.signIn);
    return id;
  }

  @override
  Future<UserModel> load() async => UserModel.fromJson(
    await client
        .from('users')
        .select()
        .eq('id', _userId)
        .eq('role', 'customer')
        .single()
        .timeout(const Duration(seconds: 15)),
  );

  @override
  Future<UserModel> save({
    required String userId,
    required String fullName,
    required String phone,
    String? avatarUrl,
  }) async {
    if (_userId != userId) {
      throw const AuthException(CustomerAccountStrings.signIn);
    }
    final name = fullName.trim();
    final normalizedPhone = normalizeCustomerContactPhone(phone);
    if (name.length < 2 || name.length > 100) {
      throw const FormatException(CustomerAccountStrings.nameRequired);
    }
    if (normalizedPhone.isEmpty) {
      throw const FormatException(CustomerAccountStrings.phoneInvalid);
    }
    // Only the customer's self-service fields are sent. Never write Auth
    // metadata, email, role, order contacts or financial fields from this form.
    final row = await client
        .from('users')
        .update({
          'full_name': name,
          'phone': normalizedPhone,
          'avatar_url': ?avatarUrl,
        })
        .eq('id', userId)
        .eq('role', 'customer')
        .select()
        .single()
        .timeout(const Duration(seconds: 15));
    return UserModel.fromJson(row);
  }

  @override
  Future<String> uploadAvatar(XFile file) async {
    final userId = _userId;
    if (await file.length() > 5 * 1024 * 1024) {
      throw const FormatException(CustomerAccountStrings.avatarError);
    }
    final decoded = image.decodeImage(await file.readAsBytes());
    if (decoded == null || decoded.width > 12000 || decoded.height > 12000) {
      throw const FormatException(CustomerAccountStrings.avatarError);
    }
    final thumbnail = image.copyResize(
      decoded,
      width: decoded.width > 512 ? 512 : decoded.width,
      height: decoded.height > 512 ? 512 : decoded.height,
      maintainAspect: true,
    );
    final reference = await _media.uploadBytes(
      purpose: R2MediaPurpose.avatar,
      bytes: image.encodeJpg(thumbnail, quality: 85),
      contentType: 'image/jpeg',
      extension: 'jpg',
    );
    // Upload tickets already bind the private object to the current JWT owner.
    if (!reference.contains('/users/$userId/avatars/')) {
      throw const FormatException(CustomerAccountStrings.avatarError);
    }
    return reference;
  }
}
