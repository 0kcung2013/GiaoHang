import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class BusinessReportRepository {
  Future<BusinessReport> fetch(String customerId, DateTime start, DateTime end);
}

class SupabaseBusinessReportRepository implements BusinessReportRepository {
  SupabaseBusinessReportRepository(this.client);
  final SupabaseClient client;
  @override
  Future<BusinessReport> fetch(
    String customerId,
    DateTime start,
    DateTime end,
  ) async {
    final actor = client.auth.currentUser?.id;
    if (actor == null) throw const AuthException('AUTH_REQUIRED');
    final result = await client
        .rpc(
          'get_customer_business_report',
          params: {
            'p_customer_id': customerId,
            'p_start': businessReportBoundary(start).toIso8601String(),
            'p_end': businessReportBoundary(end).toIso8601String(),
          },
        )
        .timeout(const Duration(seconds: 30));
    if (client.auth.currentUser?.id != actor)
      throw const AuthException('AUTH_REQUIRED');
    final report = BusinessReport.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
    if (report.customerId != customerId ||
        report.start != businessReportBoundary(start) ||
        report.end != businessReportBoundary(end)) {
      throw const FormatException('BUSINESS_REPORT_RECEIPT_INVALID');
    }
    return report;
  }
}
