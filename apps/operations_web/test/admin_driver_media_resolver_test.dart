import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/admin/screens/drivers/profile_changes/data/admin_driver_media_resolver.dart';

void main() {
  test('keeps legacy URLs and signs private object paths', () async {
    final gateway = FakeAdminDriverMediaGateway();
    final resolver = SupabaseAdminDriverMediaResolver(gateway: gateway);

    expect(
      await resolver.resolve('https://example.com/legacy.jpg'),
      'https://example.com/legacy.jpg',
    );
    expect(gateway.lastPath, isNull);

    expect(
      await resolver.resolve('user-1/request-1/id_card_front.jpg'),
      'signed:user-1/request-1/id_card_front.jpg',
    );
    expect(gateway.lastExpiresIn, 300);
  });

  test('recognizes only HTTP and HTTPS as legacy media URLs', () {
    expect(isLegacyDriverMediaUrl('http://example.com/a.jpg'), isTrue);
    expect(isLegacyDriverMediaUrl('https://example.com/a.jpg'), isTrue);
    expect(isLegacyDriverMediaUrl('user/request/a.jpg'), isFalse);
    expect(isLegacyDriverMediaUrl('javascript:alert(1)'), isFalse);
  });
}

class FakeAdminDriverMediaGateway implements AdminDriverMediaGateway {
  String? lastPath;
  int? lastExpiresIn;

  @override
  Future<String> createSignedUrl(
    String objectPath, {
    required int expiresIn,
  }) async {
    lastPath = objectPath;
    lastExpiresIn = expiresIn;
    return 'signed:$objectPath';
  }
}
