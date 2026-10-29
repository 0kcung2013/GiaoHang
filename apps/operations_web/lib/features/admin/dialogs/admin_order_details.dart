import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../support_orders/data/support_order_repository.dart';
import '../../support_orders/dialogs/support_order_detail_dialog.dart';
import '../constants/admin_strings.dart';
import '../data/admin_order_repository.dart';

Future<void> showAdminOrderDetails(
  BuildContext context,
  String id,
  AdminOrderRepository repository, {
  SupportOrderRepository? proofRepository,
}) async {
  try {
    final order = await repository.fetchOrder(id);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => SupportOrderDetailDialog(
        order: order,
        repository:
            proofRepository ??
            SupabaseSupportOrderRepository(Supabase.instance.client),
      ),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AdminStrings.loadError)));
    }
  }
}
