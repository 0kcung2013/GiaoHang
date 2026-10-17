import 'order_hub_strings.dart';
import '../../../../../core/models/order_model.dart';

enum OrderPeriod {
  all(OrderHubStrings.all),
  today(OrderHubStrings.today),
  week(OrderHubStrings.week),
  month(OrderHubStrings.month),
  custom(OrderHubStrings.pickDate);

  const OrderPeriod(this.label);
  final String label;
}

enum OrderHistoryStatus {
  all(OrderHubStrings.allStatuses),
  delivered(OrderHubStrings.delivered),
  cancelled(OrderHubStrings.cancelled),
  returned(OrderHubStrings.returned);

  const OrderHistoryStatus(this.label);
  final String label;
}

class OrderHistoryFilter {
  const OrderHistoryFilter({
    this.period = OrderPeriod.all,
    this.status = OrderHistoryStatus.all,
    this.start,
    this.end,
  });
  final OrderPeriod period;
  final OrderHistoryStatus status;
  final DateTime? start;
  final DateTime? end;

  OrderHistoryFilter withPeriod(
    OrderPeriod value, {
    DateTime? start,
    DateTime? end,
  }) =>
      OrderHistoryFilter(period: value, status: status, start: start, end: end);
  OrderHistoryFilter withStatus(OrderHistoryStatus value) =>
      OrderHistoryFilter(period: period, status: value, start: start, end: end);

  bool matches(OrderModel order, DateTime now) {
    if (status != OrderHistoryStatus.all &&
        order.effectiveStatusAt(now) != status.name) {
      return false;
    }
    final today = calendarDay(now);
    final first = switch (period) {
      OrderPeriod.all => null,
      OrderPeriod.today => today,
      OrderPeriod.week => DateTime(today.year, today.month, today.day - 6),
      OrderPeriod.month => DateTime(today.year, today.month),
      OrderPeriod.custom => start == null ? null : calendarDay(start!),
    };
    final last = period == OrderPeriod.custom && end != null
        ? calendarDay(end!)
        : today;
    final day = calendarDay(order.createdAt);
    return first == null || (!day.isBefore(first) && !day.isAfter(last));
  }

  bool get groupByDay =>
      period != OrderPeriod.all &&
      (period != OrderPeriod.custom ||
          (start != null &&
              end != null &&
              end!.difference(start!).inDays <= 31));

  String groupLabel(DateTime value) {
    final date = value.toLocal();
    return groupByDay
        ? orderHistoryDate(date)
        : 'Tháng ${date.month}/${date.year}';
  }
}

DateTime calendarDay(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String orderHistoryDate(DateTime value) {
  final date = value.toLocal();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

bool isOrderHistory(OrderModel order, DateTime now) => const {
  'delivered',
  'cancelled',
  'returned',
}.contains(order.effectiveStatusAt(now));

List<OrderModel> filterCustomerOrders(
  List<OrderModel> orders, {
  required bool history,
  required String query,
  required OrderHistoryFilter filter,
  required DateTime now,
}) {
  final search = query.trim().toLowerCase();
  return orders.where((order) {
    if (isOrderHistory(order, now) != history) return false;
    if (history && !filter.matches(order, now)) return false;
    final code = order.trackingCode.isNotEmpty
        ? order.trackingCode
        : '#${order.id.substring(0, order.id.length.clamp(0, 8))}';
    return search.isEmpty ||
        [
          code,
          order.pickupAddress,
          order.deliveryAddress,
          order.recipientName ?? '',
        ].any((value) => value.toLowerCase().contains(search));
  }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}
