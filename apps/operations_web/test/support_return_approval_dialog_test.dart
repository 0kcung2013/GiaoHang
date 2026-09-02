import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:operations_web/features/returns/dialogs/support_return_approval_dialog.dart';
import 'package:operations_web/features/returns/services/return_route_quote_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('CSKH chỉ có thể hoàn đơn về đúng nơi lấy hàng', (tester) async {
    ReturnApprovalDraft? submitted;
    final quoteService = ReturnRouteQuoteService(
      SupabaseClient(
        'https://example.supabase.co',
        'anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
      incidentOriginLoader: (_) async => null,
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'routes': [
              {'distance': 1800, 'duration': 420},
            ],
          }),
          200,
        ),
      ),
    );
    final report = RiskReport(
      id: 'risk-1',
      orderId: 'order-1',
      reportedBy: 'driver-1',
      assignedTo: 'support-1',
      category: RiskCategory.safety,
      severity: RiskSeverity.medium,
      status: RiskStatus.investigating,
      title: 'Không thể bàn giao',
      description: 'Người nhận không có mặt tại điểm giao.',
      resolution: null,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      order: const RiskOrderSummary(
        trackingCode: 'GH001',
        status: 'delivering',
        pickupAddress: '123 Đường Điểm Lấy',
        pickupLat: 10.81,
        pickupLng: 106.71,
        deliveryAddress: '456 Đường Điểm Giao',
        deliveryLat: 10.82,
        deliveryLng: 106.72,
        deliveryFee: 40000,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              submitted = await showSupportReturnApprovalDialog(
                context: context,
                report: report,
                quoteService: quoteService,
              );
            },
            child: const Text('Mở duyệt hoàn'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở duyệt hoàn'));
    await tester.pumpAndSettle();

    expect(find.text('Hoàn về nơi lấy hàng'), findsOneWidget);
    expect(find.text('123 Đường Điểm Lấy'), findsOneWidget);
    expect(find.text('Điểm xử lý'), findsNothing);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Cước giao gốc'), findsOneWidget);
    expect(find.text('40.000 đ'), findsOneWidget);
    expect(find.text('Phí hoàn hàng (50%)'), findsOneWidget);
    expect(find.text('20.000 đ'), findsOneWidget);
    expect(find.text('Tổng tài xế nhận'), findsOneWidget);
    expect(find.text('60.000 đ'), findsOneWidget);

    await tester.tap(find.byKey(const Key('approve-order-return')));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.destinationType, ReturnDestinationType.sender);
    expect(submitted!.destinationAddress, '123 Đường Điểm Lấy');
    expect(submitted!.destinationLat, 10.81);
    expect(submitted!.destinationLng, 106.71);
    expect(submitted!.driverReturnEarning, 20000);
  });
}
