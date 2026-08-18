import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:operations_web/features/risk_reports/data/risk_report_repository.dart';
import 'package:operations_web/features/risk_reports/services/risk_location_address_service.dart';
import 'package:operations_web/features/risk_reports/widgets/risk_attachment_section.dart';

void main() {
  test(
    'resolves report coordinates to a concrete Vietnamese address',
    () async {
      final service = RiskLocationAddressService(
        client: MockClient((request) async {
          expect(request.url.host, 'nominatim.openstreetmap.org');
          expect(request.url.queryParameters['accept-language'], 'vi');
          return http.Response(
            jsonEncode({
              'display_name':
                  '123 Đường DX 124, Phường Tân An, Thành phố Hồ Chí Minh',
            }),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final address = await service.resolve(10.821, 106.721);

      expect(address, contains('Đường DX 124'));
    },
  );

  testWidgets('support sees an address instead of raw coordinate numbers', (
    tester,
  ) async {
    final now = DateTime(2026, 8, 17);
    final item = RiskReportAttachmentView(
      attachment: RiskReportAttachment(
        id: 'attachment-1',
        riskReportId: 'risk-1',
        orderId: 'order-1',
        evidenceType: RiskEvidenceType.location,
        storagePath: null,
        latitude: 10.821,
        longitude: 106.721,
        capturedAt: now,
        createdAt: now,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiskAttachmentSection(
            items: [item],
            addressResolver: (_, _) async =>
                '123 Đường DX 124, Phường Tân An, Thành phố Hồ Chí Minh',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Đường DX 124'), findsOneWidget);
    expect(find.textContaining('10.82100'), findsNothing);
    expect(find.textContaining('106.72100'), findsNothing);
  });
}
