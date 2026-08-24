import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../../../../core/providers/customer_providers.dart';
import '../data/driver_profile_change_repository.dart';

final driverProfileChangeRepositoryProvider =
    Provider<DriverProfileChangeRepository>((ref) {
      return SupabaseDriverProfileChangeRepository();
    });

final currentDriverProfileChangeProvider =
    StreamProvider.autoDispose<DriverProfileChangeRequest?>((ref) {
      return ref.watch(driverProfileChangeRepositoryProvider).watchLatest();
    });

final currentDriverAccountProfileProvider =
    FutureProvider.autoDispose<DriverModel?>((ref) {
      return ref.watch(driverServiceProvider).getMyDriverAccountProfile();
    });
