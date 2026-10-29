import 'package:giaohang_storage/giaohang_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/support_order.dart';
import '../models/support_order_proof.dart';
import 'support_order_selection.dart';
import 'support_order_contacts_loader.dart';

abstract interface class SupportOrderRepository {
  Future<List<SupportOrder>> fetchOrders({String trackingCode = ''});

  Future<List<SupportOrderStatusLog>> fetchStatusLogs(String orderId);

  Future<List<SupportOrderProof>> fetchDeliveryProofs(String orderId);

  Future<String> resolveDeliveryProofUrl(String storagePath);
}

class SupabaseSupportOrderRepository implements SupportOrderRepository {
  SupabaseSupportOrderRepository(this._client, {R2MediaClient? r2Client})
    : _r2Client = r2Client;

  final SupabaseClient _client;
  final R2MediaClient? _r2Client;

  @override
  Future<List<SupportOrderProof>> fetchDeliveryProofs(String orderId) async {
    final rows = await _client
        .from('order_delivery_proofs')
        .select('stage, storage_path, captured_at')
        .eq('order_id', orderId)
        .order('captured_at');
    return rows.map(SupportOrderProof.fromJson).toList();
  }

  @override
  Future<String> resolveDeliveryProofUrl(String storagePath) async {
    final value = storagePath.trim();
    if (value.isEmpty) throw const FormatException('Empty proof reference');
    if (R2ObjectReference.isR2(value)) {
      return (_r2Client ?? R2MediaClient.supabase(client: _client)).resolveUrl(
        value,
        expiresInSeconds: 300,
      );
    }
    final uri = Uri.tryParse(value);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      return value;
    }
    if (uri == null || uri.hasScheme) {
      throw const FormatException('Invalid proof reference');
    }
    return _client.storage.from('delivery-proofs').createSignedUrl(value, 300);
  }

  @override
  Future<List<SupportOrder>> fetchOrders({String trackingCode = ''}) async {
    var query = _client.from('orders').select(supportOrderSelection);
    final normalizedCode = trackingCode.trim();
    if (normalizedCode.isNotEmpty) {
      query = query.ilike('tracking_code', '%$normalizedCode%');
    }
    final rows = await query.order('created_at', ascending: false).limit(200);
    final orders = List<Map<String, dynamic>>.from(rows);
    final contacts = await SupabaseSupportOrderContactsLoader(
      _client,
    ).fetch(orders.map((row) => row['id'].toString()).toList());
    return orders.map(contacts.enrichOrder).map(SupportOrder.fromJson).toList();
  }

  @override
  Future<List<SupportOrderStatusLog>> fetchStatusLogs(String orderId) async {
    final rows = await _client
        .from('order_status_logs')
        .select('status, title, description, created_at')
        .eq('order_id', orderId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(SupportOrderStatusLog.fromJson).toList();
  }
}
