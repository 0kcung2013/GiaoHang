import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../services/business_settings_service.dart';

final businessSettingsServiceProvider = Provider<BusinessSettingsService>(
  (ref) => BusinessSettingsService(),
);

final businessSettingsProvider = StreamProvider.autoDispose<BusinessSettings>(
  (ref) => ref.watch(businessSettingsServiceProvider).watch(),
);
