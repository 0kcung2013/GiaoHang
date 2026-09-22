import 'dart:convert';
import 'dart:typed_data';

import 'package:giaohang_storage/giaohang_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('dùng R2 Gateway production khi không truyền dart-define', () {
    final storage = R2MediaClient(accessTokenProvider: () => null);

    expect(storage.isConfigured, isTrue);
    expect(
      defaultR2GatewayBaseUrl,
      'https://giaohang-r2-gateway.sidat-giaohang.workers.dev',
    );
  });

  test('xin ticket rồi upload bytes bằng URL đã ký', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/v1/media/upload-ticket') {
        return http.Response(
          jsonEncode({
            'uploadUrl': 'https://upload.example.test/object?token=signed',
            'objectUri': 'r2://media/users/u-1/avatar/a.jpg',
          }),
          200,
        );
      }
      return http.Response('', 204);
    });
    final storage = R2MediaClient(
      accessTokenProvider: () => 'jwt',
      httpClient: client,
      gatewayBaseUrl: 'https://r2.example.test/',
    );

    final result = await storage.uploadBytes(
      purpose: R2MediaPurpose.avatar,
      bytes: Uint8List.fromList([1, 2, 3]),
      contentType: 'image/jpeg',
      extension: 'jpg',
    );

    expect(result, 'r2://media/users/u-1/avatar/a.jpg');
    expect(requests, hasLength(2));
    expect(requests.first.headers['authorization'], 'Bearer jwt');
    expect(requests.last.method, 'PUT');
  });

  test('giữ nguyên URL Supabase cũ khi resolve', () async {
    final storage = R2MediaClient(
      accessTokenProvider: () => null,
      gatewayBaseUrl: '',
    );

    expect(
      await storage.resolveUrl('https://project.supabase.co/storage/photo.jpg'),
      'https://project.supabase.co/storage/photo.jpg',
    );
  });
}
