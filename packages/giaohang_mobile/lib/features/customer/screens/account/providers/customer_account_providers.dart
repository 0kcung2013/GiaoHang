import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/models/user_model.dart';
import '../../../../../core/providers/customer_providers.dart';
import '../data/customer_account_repository.dart';

final customerAccountUserIdProvider = Provider<String?>(
  (ref) => Supabase.instance.client.auth.currentUser?.id,
);

final customerAccountRepositoryProvider = Provider<CustomerAccountRepository>(
  (ref) => SupabaseCustomerAccountRepository(Supabase.instance.client),
);

final customerAccountProfileProvider = FutureProvider.autoDispose<UserModel?>((
  ref,
) {
  final id = ref.watch(customerAccountUserIdProvider);
  if (id == null) return null;
  return ref.watch(customerProfileProvider(id).future);
});

void refreshCustomerAccount(WidgetRef ref, String userId) {
  ref.invalidate(customerProfileProvider(userId));
  ref.invalidate(customerAccountProfileProvider);
}
