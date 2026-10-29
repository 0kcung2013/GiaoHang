import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/customer_payment_repository.dart';
import '../models/customer_payment.dart';

final customerPaymentRepositoryProvider = Provider<CustomerPaymentRepository>(
  (ref) => SupabaseCustomerPaymentRepository(Supabase.instance.client),
);

final customerPaymentsProvider = FutureProvider.autoDispose
    .family<List<CustomerPayment>, CustomerPaymentRange>(
      (ref, range) => ref.watch(customerPaymentRepositoryProvider).fetch(range),
    );
