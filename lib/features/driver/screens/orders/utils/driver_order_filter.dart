import '../../../../../core/models/order_model.dart';
import '../../home/utils/driver_home_formatters.dart';

enum DriverOrderFilter {
  available('Available'),
  active('Active'),
  completed('Completed');

  final String label;

  const DriverOrderFilter(this.label);

  String get emptyTitle {
    return switch (this) {
      DriverOrderFilter.available => 'Không có đơn mới',
      DriverOrderFilter.active => 'Chưa có đơn đang giao',
      DriverOrderFilter.completed => 'Chưa có đơn hoàn thành',
    };
  }

  String get emptyMessage {
    return switch (this) {
      DriverOrderFilter.available =>
        'Các đơn chưa có tài xế sẽ xuất hiện ở đây.',
      DriverOrderFilter.active =>
        'Các đơn đã nhận và đang xử lý sẽ xuất hiện ở đây.',
      DriverOrderFilter.completed =>
        'Các đơn đã giao thành công sẽ xuất hiện ở đây.',
    };
  }

  String get title {
    return switch (this) {
      DriverOrderFilter.available => 'Đơn có thể nhận',
      DriverOrderFilter.active => 'Đơn đang xử lý',
      DriverOrderFilter.completed => 'Đơn đã hoàn thành',
    };
  }

  List<OrderModel> filter({
    required List<OrderModel> availableOrders,
    required List<OrderModel> driverOrders,
  }) {
    return switch (this) {
      DriverOrderFilter.available => availableOrders,
      DriverOrderFilter.active =>
        driverOrders.where(isActiveDriverOrder).toList(),
      DriverOrderFilter.completed =>
        driverOrders.where((order) => order.status == 'delivered').toList(),
    };
  }
}
