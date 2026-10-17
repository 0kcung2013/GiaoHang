import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/driver_cancellation_repository.dart';
import 'models/driver_acceptance_state.dart';

final driverCancellationRepositoryProvider =
    Provider<DriverCancellationRepository>(
      (ref) => DriverCancellationRepository(),
    );

final driverAcceptanceStateProvider = StreamProvider.autoDispose
    .family<DriverAcceptanceState, String>((ref, userId) {
      return ref
          .watch(driverCancellationRepositoryProvider)
          .watchAcceptanceState(userId);
    });
