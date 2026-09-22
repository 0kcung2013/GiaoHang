import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'r2_media_purpose.dart';
import 'r2_object_reference.dart';

typedef R2AccessTokenProvider = String? Function();

const String defaultR2GatewayBaseUrl =
    'https://giaohang-r2-gateway.sidat-giaohang.workers.dev';

class R2MediaException implements Exception {
  const R2MediaException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Client gọi R2 Gateway. Flutter không bao giờ giữ R2 access key.
class R2MediaClient {
  R2MediaClient({
    required R2AccessTokenProvider accessTokenProvider,
    http.Client? httpClient,
    String gatewayBaseUrl = const String.fromEnvironment(
      'GIAOHANG_R2_GATEWAY_URL',
      defaultValue: defaultR2GatewayBaseUrl,
    ),
  }) : _accessTokenProvider = accessTokenProvider,
       _httpClient = httpClient ?? http.Client(),
       _gatewayBaseUrl = _normalizeBaseUrl(gatewayBaseUrl);

  factory R2MediaClient.supabase({
    SupabaseClient? client,
    http.Client? httpClient,
    String gatewayBaseUrl = const String.fromEnvironment(
      'GIAOHANG_R2_GATEWAY_URL',
      defaultValue: defaultR2GatewayBaseUrl,
    ),
  }) {
    final supabase = client ?? Supabase.instance.client;
    return R2MediaClient(
      accessTokenProvider: () => supabase.auth.currentSession?.accessToken,
      httpClient: httpClient,
      gatewayBaseUrl: gatewayBaseUrl,
    );
  }

  final R2AccessTokenProvider _accessTokenProvider;
  final http.Client _httpClient;
  final String _gatewayBaseUrl;

  bool get isConfigured => _gatewayBaseUrl.isNotEmpty;

  Future<String> uploadBytes({
    required R2MediaPurpose purpose,
    required Uint8List bytes,
    required String contentType,
    required String extension,
    String? contextId,
    String? groupId,
    String? stage,
  }) async {
    if (bytes.isEmpty) {
      throw const R2MediaException('Không thể tải tệp rỗng lên R2.');
    }

    final ticket = await _postJson('/v1/media/upload-ticket', {
      'purpose': purpose.apiValue,
      'contentType': contentType,
      'extension': extension.replaceFirst('.', '').toLowerCase(),
      if (contextId != null) 'contextId': contextId,
      if (groupId != null) 'groupId': groupId,
      if (stage != null) 'stage': stage,
      'size': bytes.length,
    });
    final uploadUrl = ticket['uploadUrl']?.toString();
    final objectUri = ticket['objectUri']?.toString();
    if (uploadUrl == null || objectUri == null) {
      throw const R2MediaException(
        'R2 Gateway trả về upload ticket không hợp lệ.',
      );
    }

    final response = await _httpClient.put(
      Uri.parse(uploadUrl),
      headers: {'content-type': contentType},
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw R2MediaException(
        _errorMessage(response, fallback: 'Không thể tải tệp lên R2.'),
        statusCode: response.statusCode,
      );
    }
    return objectUri;
  }

  Future<String> resolveUrl(
    String storedValue, {
    int expiresInSeconds = 600,
  }) async {
    final normalized = storedValue.trim();
    if (!R2ObjectReference.isR2(normalized)) return normalized;

    final response = await _postJson('/v1/media/download-ticket', {
      'objectUri': normalized,
      'expiresIn': expiresInSeconds,
    });
    final downloadUrl = response['downloadUrl']?.toString();
    if (downloadUrl == null || downloadUrl.isEmpty) {
      throw const R2MediaException(
        'R2 Gateway không trả về đường dẫn tải ảnh.',
      );
    }
    return downloadUrl;
  }

  Future<void> deleteObject(String objectUri) async {
    if (!R2ObjectReference.isR2(objectUri)) return;
    await _postJson('/v1/media/delete', {'objectUri': objectUri});
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> payload,
  ) async {
    if (!isConfigured) {
      throw const R2MediaException('Chưa cấu hình GIAOHANG_R2_GATEWAY_URL.');
    }
    final token = _accessTokenProvider();
    if (token == null || token.isEmpty) {
      throw const R2MediaException('Phiên đăng nhập đã hết hạn.');
    }

    final response = await _httpClient.post(
      Uri.parse('$_gatewayBaseUrl$path'),
      headers: {
        'authorization': 'Bearer $token',
        'content-type': 'application/json',
      },
      body: jsonEncode(payload),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw R2MediaException(
        _errorMessage(response, fallback: 'R2 Gateway không phản hồi.'),
        statusCode: response.statusCode,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const R2MediaException('Phản hồi R2 Gateway không hợp lệ.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  static String _errorMessage(
    http.Response response, {
    required String fallback,
  }) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] is String)
        return body['error'] as String;
    } catch (_) {
      // Phản hồi lỗi không nhất thiết là JSON.
    }
    return fallback;
  }

  static String _normalizeBaseUrl(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
