import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/free_pick_service.dart';
import '../../../../core/providers/customer_providers.dart';

final freePickServiceProvider = Provider<FreePickService>((ref) {
  return FreePickService(
    notificationService: ref.watch(notificationServiceProvider),
  );
});
