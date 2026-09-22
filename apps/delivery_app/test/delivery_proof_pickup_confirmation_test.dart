import 'dart:convert';
import 'dart:typed_data';

import 'package:delivery_app/core/models/delivery_proof_model.dart';
import 'package:delivery_app/core/services/delivery_proof_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_storage/giaohang_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'pickup succeeds only after the server commits its confirmation',
    () async {
      final requests = <String>[];
      final client = await _client(requests);
      addTearDown(client.dispose);

      final proof = await _submit(client, DeliveryProofStage.pickup, requests);

      expect(proof.stage, DeliveryProofStage.pickup);
      expect(requests, ['upload', 'proof', 'confirmation']);
    },
  );

  test(
    'a saved photo does not report pickup success if confirmation fails',
    () async {
      final requests = <String>[];
      final client = await _client(requests, rejectConfirmation: true);
      addTearDown(client.dispose);

      await expectLater(
        _submit(client, DeliveryProofStage.pickup, requests),
        throwsA(isA<PostgrestException>()),
      );
      expect(requests, ['upload', 'proof', 'confirmation']);
    },
  );

  test(
    'delivery proof does not invoke the pickup confirmation command',
    () async {
      final requests = <String>[];
      final client = await _client(requests);
      addTearDown(client.dispose);

      await _submit(client, DeliveryProofStage.delivery, requests);

      expect(requests, ['upload', 'proof']);
    },
  );
}

Future<DeliveryProofModel> _submit(
  SupabaseClient client,
  DeliveryProofStage stage,
  List<String> requests,
) {
  final r2Client = R2MediaClient(
    accessTokenProvider: () => client.auth.currentSession?.accessToken,
    gatewayBaseUrl: 'https://r2.example.test',
    httpClient: MockClient((request) async {
      if (request.url.path == '/v1/media/upload-ticket') {
        return http.Response(
          jsonEncode({
            'uploadUrl': 'https://r2.example.test/v1/ticket/upload?signed=1',
            'objectUri':
                'r2://media/orders/order-1/delivery-proofs/${stage.value}/proof',
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      if (request.method == 'PUT' && request.url.path == '/v1/ticket/upload') {
        requests.add('upload');
        return http.Response('', 201, request: request);
      }
      throw StateError(
        'Unexpected R2 request: ${request.method} ${request.url}',
      );
    }),
  );
  return DeliveryProofService(client: client, r2Client: r2Client).submitProof(
    orderId: 'order-1',
    driverId: 'driver-1',
    stage: stage,
    image: XFile.fromData(
      Uint8List.fromList([1, 2, 3]),
      name: 'proof.png',
      mimeType: 'image/png',
    ),
    capturedLat: 11.02,
    capturedLng: 106.62,
  );
}

Future<SupabaseClient> _client(
  List<String> requests, {
  bool rejectConfirmation = false,
}) async {
  final client = SupabaseClient(
    'http://localhost:54321',
    'test-anon-key',
    httpClient: MockClient((request) async {
      dynamic response;
      var status = 200;
      final path = request.url.path;
      if (path.endsWith('/auth/v1/token')) {
        response = {
          'access_token': 'test-access-token',
          'refresh_token': 'test-refresh-token',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': 'driver-1',
            'aud': 'authenticated',
            'role': 'authenticated',
            'email': 'driver@example.com',
            'app_metadata': <String, dynamic>{},
            'user_metadata': <String, dynamic>{},
            'created_at': '2026-09-15T00:00:00Z',
          },
        };
      } else if (path.endsWith('/rest/v1/order_delivery_proofs')) {
        requests.add('proof');
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        response = {'id': 'proof-1', ...payload};
      } else if (path.endsWith('/rpc/confirm_driver_pickup')) {
        requests.add('confirmation');
        expect(jsonDecode(request.body), {'p_order_id': 'order-1'});
        status = rejectConfirmation ? 400 : 200;
        response = rejectConfirmation
            ? {'code': 'P0001', 'message': 'ORDER_NOT_PICKING_UP'}
            : '2026-09-15T00:00:00Z';
      } else {
        throw StateError('Unexpected request: ${request.method} $path');
      }
      return http.Response(
        jsonEncode(response),
        status,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );
  await client.auth.signInWithPassword(
    email: 'driver@example.com',
    password: 'test-password',
  );
  return client;
}
