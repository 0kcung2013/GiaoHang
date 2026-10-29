import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:giaohang_config/giaohang_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessSettingsService {
  BusinessSettingsService({SupabaseClient? client}) : _client = client;
  final SupabaseClient? _client;
  BusinessSettingsLive get _live =>
      BusinessSettingsLive(_client ?? Supabase.instance.client);

  /// Không dùng giá mặc định khi mạng lỗi: tránh báo giá sai cấu hình đang có hiệu lực.
  Future<BusinessSettings> load() => _live.load();

  Future<BusinessSettings> contact() => _live.contact();
  Stream<BusinessSettings> watch() async* {
    yield* _live.watch();
  }

  Stream<BusinessSettings> watchContact() async* {
    yield* _live.watchContact();
  }
}
