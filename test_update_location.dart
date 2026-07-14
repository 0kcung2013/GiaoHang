import 'package:supabase/supabase.dart';

void main(List<String> args) async {
  if (args.length < 3) {
    print('Cách dùng: dart run test_update_location.dart <driver_id> <latitude> <longitude>');
    print('Ví dụ (Giả lập ở Mỹ): dart run test_update_location.dart 847d04e3-3e1b-4d43-a60d-83b6cb595db1 37.4219999 -122.0840575');
    print('Ví dụ (Shipper ở Việt Nam): dart run test_update_location.dart 847d04e3-3e1b-4d43-a60d-83b6cb595db1 10.957533 106.64322');
    return;
  }

  final driverId = args[0];
  final lat = double.tryParse(args[1]);
  final lng = double.tryParse(args[2]);

  if (lat == null || lng == null) {
    print('Toạ độ không hợp lệ.');
    return;
  }

  final client = SupabaseClient(
    'https://erlpzwfbpjogvaulcxni.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVybHB6d2ZicGpvZ3ZhdWxjeG5pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzNDY5MzcsImV4cCI6MjA5NDkyMjkzN30.D4i2smi6ONr34Q8G7nFNoNwi9DbHiVKPJD-wgGRepTY',
  );

  print('Đang cập nhật vị trí tài xế $driverId thành: $lat, $lng...');
  try {
    await client
        .from('drivers')
        .update({
          'current_lat': lat,
          'current_lng': lng,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', driverId);
    print('Cập nhật thành công lên database Supabase!');
  } catch (e) {
    print('Lỗi cập nhật: $e');
  }
}
