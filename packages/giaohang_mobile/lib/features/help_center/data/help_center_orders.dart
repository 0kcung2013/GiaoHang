import '../../../core/mobile_app_role.dart';
import '../../../core/models/order_model.dart';
import '../../../core/services/customer_order_service.dart';
import '../../../core/services/driver_order_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef HelpOrdersLoader = Future<List<OrderModel>> Function(String userId);

Future<List<OrderModel>> loadHelpOrders(MobileAppRole role, String userId) =>
    role == MobileAppRole.driver
    ? DriverOrderService(
        client: Supabase.instance.client,
      ).getDriverOrders(userId)
    : CustomerOrderService().getCustomerOrders(userId);

List<OrderModel> sortHelpOrders(Iterable<OrderModel> orders) =>
    orders.toList()..sort((left, right) {
      final leftClosed = _isClosed(left.status);
      final rightClosed = _isClosed(right.status);
      if (leftClosed != rightClosed) return leftClosed ? 1 : -1;
      return right.updatedAt.compareTo(left.updatedAt);
    });

bool _isClosed(String status) =>
    const {'delivered', 'cancelled', 'returned'}.contains(status);

String helpOrderStatus(String status) => switch (status) {
  'pending' => 'Chờ xác nhận',
  'confirmed' => 'Đang tìm tài xế',
  'assigned' => 'Đã có tài xế',
  'picking_up' => 'Đang lấy hàng',
  'delivering' => 'Đang giao hàng',
  'delivered' => 'Đã giao',
  'cancelled' => 'Đã hủy',
  'return_approved' => 'Đã duyệt hoàn hàng',
  'returning' => 'Đang hoàn hàng',
  'returned' => 'Đã hoàn hàng',
  'risk_hold' => 'Đang xử lý sự cố',
  _ => 'Đang xử lý',
};
