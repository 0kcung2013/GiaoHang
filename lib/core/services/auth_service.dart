import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? Uri.base.origin : null,
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  String? getCurrentRole() {
    return _supabase.auth.currentUser?.userMetadata?['role'] as String?;
  }

  Future<String?> fetchUserRole() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final result = await _supabase
        .from('users')
        .select('role')
        .eq('id', user.id)
        .single();
    return result['role'] as String?;
  }
}
