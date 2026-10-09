import 'dart:typed_data';
import 'dart:convert';

import 'package:delivery_app/features/order_help/controllers/support_chat_attachment_draft.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:giaohang_storage/giaohang_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const uri = 'r2://media/users/driver/order-cargo/order/support-chat/one.jpg';
  final png = Uint8List.fromList(img.encodePng(img.Image(width: 1, height: 1)));

  test(
    'private image references round trip without changing ordinary messages',
    () {
      final body = CaseMessageContent(
        text: 'Hàng bị móp',
        images: [uri],
      ).encode();
      final content = CaseMessageContent.decode(body);
      expect(content.text, 'Hàng bị móp');
      expect(content.images, [uri]);
      expect(
        CaseMessageContent.decode('văn bản\nnguyên vẹn').text,
        'văn bản\nnguyên vẹn',
      );
      expect(
        CaseMessageContent(text: '', images: [uri]).encode(),
        startsWith('Ảnh đính kèm\n\n'),
      );
      const unsafe =
          'Nội dung\n\n[Ảnh đính kèm](https://example.com/private.jpg)';
      expect(CaseMessageContent.decode(unsafe).images, isEmpty);
      expect(CaseMessageContent.decode(unsafe).text, unsafe);
    },
  );

  test(
    'rejects public links, other user media and excessive attachment references',
    () {
      for (final value in [
        'https://example.com/a.jpg',
        'r2://media/users/driver/driver-kyc/a.jpg',
        '$uri?token=secret',
      ]) {
        expect(
          () => CaseMessageContent(text: 'Ảnh', images: [value]).encode(),
          throwsArgumentError,
        );
      }
      expect(
        () => CaseMessageContent(
          text: 'Ảnh',
          images: List.filled(4, uri),
        ).encode(),
        throwsArgumentError,
      );
    },
  );

  test('an uploaded image is reused after a message send fails', () async {
    var uploads = 0;
    final draft = SupportChatAttachmentDraft(
      contextId: 'order',
      pickImages: () async => [XFile.fromData(png, name: 'image.png')],
      prepareImage: (bytes) async => bytes,
      uploadImage: (bytes, orderId) async {
        uploads++;
        expect(orderId, 'order');
        return uri;
      },
    );
    await draft.pick();
    expect(await draft.upload(), [uri]);
    expect(await draft.upload(), [uri]);
    expect(uploads, 1);
    draft.remove(draft.images.single);
    expect(draft.images, isEmpty);
  });

  test(
    'R2 upload reuses private cargo tickets and stores a stable chat URI',
    () async {
      final client = MockClient((request) async {
        if (request.method == 'PUT') {
          expect(request.headers['content-type'], 'image/jpeg');
          return http.Response('', 201);
        }
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(request.url.path, '/v1/media/upload-ticket');
        expect(request.headers['authorization'], 'Bearer token');
        expect(payload['purpose'], 'order_cargo');
        expect(payload['stage'], 'support-chat');
        expect(payload['contextId'], 'order');
        return http.Response(
          jsonEncode({
            'objectUri': uri,
            'uploadUrl': 'https://r2.example/upload',
          }),
          200,
        );
      });
      addTearDown(client.close);
      final draft = SupportChatAttachmentDraft(
        contextId: 'order',
        pickImages: () async => [XFile.fromData(png, name: 'image.png')],
        r2Client: R2MediaClient(
          accessTokenProvider: () => 'token',
          httpClient: client,
          gatewayBaseUrl: 'https://r2.example',
        ),
      );
      await draft.pick();
      expect(await draft.upload(), [uri]);
      expect(draft.images.single.objectUri, uri);
    },
  );

  test('too many images and oversized files do not change the draft', () async {
    final draft = SupportChatAttachmentDraft(
      contextId: 'order',
      pickImages: () async =>
          List.generate(4, (i) => XFile.fromData(png, name: '$i.png')),
      prepareImage: (bytes) async => bytes,
    );
    await expectLater(draft.pick(), throwsA(isA<R2MediaException>()));
    expect(draft.images, isEmpty);
    final oversized = SupportChatAttachmentDraft(
      contextId: 'order',
      pickImages: () async => [
        XFile.fromData(Uint8List(SupportChatAttachmentDraft.maxBytes + 1)),
      ],
      prepareImage: (bytes) async => bytes,
    );
    await expectLater(oversized.pick(), throwsA(isA<R2MediaException>()));
    expect(oversized.images, isEmpty);
  });

  test(
    'real image preparation compresses JPEG and rejects non images',
    () async {
      final draft = SupportChatAttachmentDraft(
        contextId: 'order',
        pickImages: () async => [XFile.fromData(png, name: 'image.png')],
      );
      await draft.pick();
      expect(draft.images.single.bytes.take(2), [0xff, 0xd8]);
      final invalid = SupportChatAttachmentDraft(
        contextId: 'order',
        pickImages: () async => [
          XFile.fromData(Uint8List.fromList([1, 2, 3])),
        ],
      );
      await expectLater(invalid.pick(), throwsA(isA<R2MediaException>()));
      expect(invalid.images, isEmpty);
    },
  );
}
