import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://erlpzwfbpjogvaulcxni.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVybHB6d2ZicGpvZ3ZhdWxjeG5pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzNDY5MzcsImV4cCI6MjA5NDkyMjkzN30.D4i2smi6ONr34Q8G7nFNoNwi9DbHiVKPJD-wgGRepTY',
  );

  print('Querying drivers...');
  try {
    final drivers = await client.from('drivers').select();
    print('Drivers:');
    for (final d in drivers) {
      print('Driver ID: ${d['id']}, User ID: ${d['user_id']}, Lat: ${d['current_lat']}, Lng: ${d['current_lng']}, Available: ${d['is_available']}');
    }
  } catch (e) {
    print('Error querying drivers: $e');
  }

  print('\nQuerying orders...');
  try {
    final orders = await client.from('orders').select();
    print('Orders:');
    for (final o in orders) {
      print('Order ID: ${o['id']}, Status: ${o['status']}, Driver ID: ${o['driver_id']}, Pickup: (${o['pickup_lat']}, ${o['pickup_lng']}), Delivery: (${o['delivery_lat']}, ${o['delivery_lng']})');
    }
  } catch (e) {
    print('Error querying orders: $e');
  }
}
