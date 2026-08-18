import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:test/test.dart';

void main() {
  test('parses a returning mission and preserves database values', () {
    final value = OrderReturn.fromJson({
      'id': 'return-1',
      'order_id': 'order-1',
      'risk_report_id': 'risk-1',
      'driver_id': 'driver-1',
      'status': 'returning',
      'destination_type': 'processing_center',
      'destination_address': 'Kho trung tâm',
      'destination_lat': 10.8,
      'destination_lng': 106.7,
      'route_origin_lat': 10.81,
      'route_origin_lng': 106.71,
      'route_distance_m': 3200,
      'route_duration_s': 720,
      'quote_source': 'osrm',
      'reason_code': 'recipient_refused',
      'fee_payer': 'platform',
      'customer_return_charge': 0,
      'driver_return_earning': 26000,
      'fee_status': 'waived',
      'approved_at': '2026-08-16T07:00:00Z',
      'started_at': '2026-08-16T07:05:00Z',
      'created_at': '2026-08-16T07:00:00Z',
      'updated_at': '2026-08-16T07:05:00Z',
    });

    expect(value.status, OrderReturnStatus.returning);
    expect(value.destinationType, ReturnDestinationType.processingCenter);
    expect(value.feePayer, ReturnFeePayer.platform);
    expect(value.driverReturnEarning, 26000);
    expect(value.canComplete, isTrue);
    expect(value.toJson()['destination_type'], 'processing_center');
  });

  test('approval draft maps typed values to RPC parameters', () {
    const draft = ReturnApprovalDraft(
      reportId: 'risk-1',
      reasonCode: 'recipient_absent',
      destinationType: ReturnDestinationType.sender,
      destinationAddress: 'Điểm lấy hàng',
      destinationLat: 10.8,
      destinationLng: 106.7,
      routeOriginLat: 10.82,
      routeOriginLng: 106.72,
      routeDistanceMeters: 4000,
      routeDurationSeconds: 900,
      quoteSource: ReturnQuoteSource.fallback,
      feePayer: ReturnFeePayer.customer,
      customerReturnCharge: 28000,
      driverReturnEarning: 28000,
    );

    expect(draft.toRpcParams(), containsPair('p_fee_payer', 'customer'));
    expect(draft.toRpcParams(), containsPair('p_destination_type', 'sender'));
    expect(draft.toRpcParams(), containsPair('p_route_distance_m', 4000));
  });
}
