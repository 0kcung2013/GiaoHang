import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/providers/customer_providers.dart';

final driverGpsDebugUserProvider = Provider<User? Function()>(
  (ref) =>
      () => Supabase.instance.client.auth.currentUser,
);

// Diagnostics compares against a fresh server read, independently of GPS.
final driverGpsDebugProfileProvider =
    Provider<Future<DriverModel?> Function(String)>(
      (ref) =>
          (id) => ref.read(driverServiceProvider).getDriverByUserId(id),
    );
