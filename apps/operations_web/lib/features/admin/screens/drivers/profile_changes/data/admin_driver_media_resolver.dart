import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AdminDriverMediaResolver {
  Future<String?> resolve(String? storedValue);
}

abstract interface class AdminDriverMediaGateway {
  Future<String> createSignedUrl(String objectPath, {required int expiresIn});
}

bool isLegacyDriverMediaUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

class SupabaseAdminDriverMediaResolver implements AdminDriverMediaResolver {
  SupabaseAdminDriverMediaResolver({AdminDriverMediaGateway? gateway})
    : _gateway = gateway ?? SupabaseAdminDriverMediaGateway();

  final AdminDriverMediaGateway _gateway;

  @override
  Future<String?> resolve(String? storedValue) async {
    final normalized = storedValue?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    if (isLegacyDriverMediaUrl(normalized)) return normalized;
    return _gateway.createSignedUrl(normalized, expiresIn: 300);
  }
}

class SupabaseAdminDriverMediaGateway implements AdminDriverMediaGateway {
  SupabaseAdminDriverMediaGateway({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<String> createSignedUrl(String objectPath, {required int expiresIn}) {
    return _client.storage
        .from('driver-profile-request-files')
        .createSignedUrl(objectPath, expiresIn);
  }
}
