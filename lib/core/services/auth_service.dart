import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? Uri.base.origin : null,
      queryParams: const {'prompt': 'select_account'},
    );
  }

  Future<User?> signUpCustomer({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'phone': phone, 'role': 'customer'},
    );

    if (response.user == null) {
      throw Exception('Đăng ký thất bại');
    }

    return response.user;
  }

  /// Chỉ tạo Auth user (role driver). Gọi [createDriverProfile] sau khi upload KYC.
  Future<User?> signUpDriverAuth({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'phone': phone, 'role': 'driver'},
    );

    if (response.user == null) {
      throw Exception('Đăng ký thất bại');
    }
    return response.user;
  }

  Future<void> createDriverProfile({
    required String email,
    required String fullName,
    required String phone,
    required String vehicleType,
    required String licensePlate,
    String? vehicleBrandModel,
    String? vehicleColor,
    String? avatarUrl,
    String? idCardNumber,
    String? idCardFrontUrl,
    String? idCardBackUrl,
    String? driverLicenseNumber,
    String? driverLicenseUrl,
    String? vehiclePhotoUrl,
  }) async {
    await _supabase.rpc('create_driver_profile', params: {
      'p_email': email,
      'p_full_name': fullName,
      'p_phone': phone,
      'p_vehicle_type': vehicleType,
      'p_license_plate': licensePlate,
      'p_vehicle_brand_model': vehicleBrandModel,
      'p_vehicle_color': vehicleColor,
      'p_avatar_url': avatarUrl,
      'p_id_card_number': idCardNumber,
      'p_id_card_front_url': idCardFrontUrl,
      'p_id_card_back_url': idCardBackUrl,
      'p_driver_license_number': driverLicenseNumber,
      'p_driver_license_url': driverLicenseUrl,
      'p_vehicle_photo_url': vehiclePhotoUrl,
    });
  }

  /// Backward-compatible: auth + profile (không KYC đầy đủ).
  Future<User?> signUpDriver({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String vehicleType,
    required String licensePlate,
    String? vehicleBrandModel,
    String? vehicleColor,
    String? avatarUrl,
    String? idCardNumber,
    String? idCardFrontUrl,
    String? idCardBackUrl,
    String? driverLicenseNumber,
    String? driverLicenseUrl,
    String? vehiclePhotoUrl,
  }) async {
    final user = await signUpDriverAuth(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
    );

    try {
      await createDriverProfile(
        email: email,
        fullName: fullName,
        phone: phone,
        vehicleType: vehicleType,
        licensePlate: licensePlate,
        vehicleBrandModel: vehicleBrandModel,
        vehicleColor: vehicleColor,
        avatarUrl: avatarUrl,
        idCardNumber: idCardNumber,
        idCardFrontUrl: idCardFrontUrl,
        idCardBackUrl: idCardBackUrl,
        driverLicenseNumber: driverLicenseNumber,
        driverLicenseUrl: driverLicenseUrl,
        vehiclePhotoUrl: vehiclePhotoUrl,
      );
    } catch (_) {
      await _supabase.auth.signOut();
      rethrow;
    }

    return user;
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  Future<String?> fetchUserRole() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    try {
      final result = await _supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single();
      return result['role'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String> ensureUserRecord() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 'customer';

    final result = await _supabase.rpc('ensure_user_record');
    return result as String? ?? 'customer';
  }
}
