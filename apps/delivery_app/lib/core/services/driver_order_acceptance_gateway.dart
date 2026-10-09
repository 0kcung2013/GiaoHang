import 'package:supabase_flutter/supabase_flutter.dart';

/// Server quotes the route and commits acceptance + deadline atomically.
Future<dynamic> acceptDriverOrderWithDeadline(
  SupabaseClient client,
  String orderId, {
  bool freePick = false,
  bool existingOnly = false,
}) async {
  try {
    final response = await client.functions.invoke(
      'accept-driver-order',
      body: {
        'order_id': orderId,
        'free_pick': freePick,
        'existing_only': existingOnly,
      },
    );
    return response.data;
  } on FunctionException catch (error) {
    final details = error.details;
    throw Exception(
      details is Map
          ? details['error'] ?? error.reasonPhrase
          : error.reasonPhrase,
    );
  }
}
