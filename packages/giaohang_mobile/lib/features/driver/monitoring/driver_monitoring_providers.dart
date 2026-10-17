import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Poll riêng vẫn đọc được kết quả thu hồi khi RLS không còn trả order cho tài xế cũ.
final driverMonitoringProvider = StreamProvider.autoDispose
    .family<DriverMonitoringSnapshot, String>((ref, orderId) {
      final controller = StreamController<DriverMonitoringSnapshot>();
      var pending = false;
      Future<void> refresh() async {
        if (pending || controller.isClosed) return;
        pending = true;
        try {
          final row = await Supabase.instance.client
              .rpc(
                'get_order_driver_monitoring',
                params: {'p_order_id': orderId},
              )
              .timeout(const Duration(seconds: 12));
          if (!controller.isClosed) {
            controller.add(
              DriverMonitoringSnapshot.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            );
          }
        } catch (error, stack) {
          if (!controller.isClosed) controller.addError(error, stack);
        } finally {
          pending = false;
        }
      }

      unawaited(refresh());
      final timer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => unawaited(refresh()),
      );
      ref.onDispose(() {
        timer.cancel();
        unawaited(controller.close());
      });
      return controller.stream;
    });

/// Cùng một sự cố có thể xuất hiện ở Shell và Map; chỉ xử lý UI một lần.
final handledDriverMonitoringReleasesProvider = StateProvider<Set<String>>(
  (ref) => {},
);
