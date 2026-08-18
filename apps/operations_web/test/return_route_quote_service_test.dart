import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:operations_web/features/returns/services/return_route_quote_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const order = RiskOrderSummary(
    trackingCode: 'GH001',
    status: 'delivering',
    pickupAddress: 'Điểm lấy',
    pickupLat: 10.81,
    pickupLng: 106.71,
    deliveryAddress: 'Điểm giao',
    deliveryLat: 10.82,
    deliveryLng: 106.72,
    driverId: 'driver-user-1',
  );

  test('dùng GPS được chụp lúc tài xế gửi báo cáo rủi ro', () async {
    Uri? requestedUri;
    final service = ReturnRouteQuoteService(
      _client(),
      currentDriverOriginLoader: (_) async => (11.0308, 106.62202),
      incidentOriginLoader: (_) async => (10.821, 106.721),
      httpClient: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'routes': [
              {'distance': 1800, 'duration': 420},
            ],
          }),
          200,
        );
      }),
    );

    final quote = await service.quote(
      riskReportId: 'risk-1',
      order: order,
      destinationLat: order.pickupLat!,
      destinationLng: order.pickupLng!,
    );

    expect(quote.originLat, 10.821);
    expect(quote.originLng, 106.721);
    expect(requestedUri!.path, contains('106.721,10.821;106.71,10.81'));
  });

  test('fallback về GPS hồ sơ khi báo cáo cũ không có vị trí', () async {
    final service = ReturnRouteQuoteService(
      _client(),
      currentDriverOriginLoader: (_) async => (11.0308, 106.62202),
      incidentOriginLoader: (_) async => throw StateError('missing snapshot'),
      httpClient: MockClient((_) async => http.Response('', 503)),
    );

    final quote = await service.quote(
      riskReportId: 'risk-1',
      order: order,
      destinationLat: order.pickupLat!,
      destinationLng: order.pickupLng!,
    );

    expect(quote.originLat, 11.0308);
    expect(quote.originLng, 106.62202);
  });
}

SupabaseClient _client() => SupabaseClient(
  'https://example.supabase.co',
  'anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);
