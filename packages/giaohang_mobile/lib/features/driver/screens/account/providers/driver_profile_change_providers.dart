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
      final changes = ref
          .watch(driverProfileChangeRepositoryProvider)
          .watchLatest();
      return changes.map((request) {
        if (request?.status == DriverProfileChangeStatus.approved ||
            request?.status == DriverProfileChangeStatus.conflicted) {
          ref.invalidate(currentDriverAccountProfileProvider);
        }
        return request;
      });
    });

final currentDriverAccountProfileProvider =
    FutureProvider.autoDispose<DriverModel?>((ref) {
      return ref.watch(driverServiceProvider).getMyDriverAccountProfile();
    });
