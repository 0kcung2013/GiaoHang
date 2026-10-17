part of 'tracking_screen.dart';

class _PackageInfoCard extends StatelessWidget {
  final OrderModel order;

  const _PackageInfoCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final displayCode = order.trackingCode.isEmpty
        ? '#${order.id.substring(0, order.id.length >= 8 ? 8 : order.id.length)}'
        : order.trackingCode;
    final recipient = _joinNonEmpty([
      order.recipientName,
      order.recipientPhone,
    ]);

    return _TrackingExpandableCard(
      title: 'Thông tin gói hàng',
      subtitle: 'Địa chỉ, người nhận, dịch vụ và thanh toán',
      icon: Icons.inventory_2_rounded,
      iconColor: AppColors.info,
      child: Column(
        children: [
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(label: 'Mã đơn', value: displayCode),
          _InfoRow(
            label: 'Trạng thái',
            value: _statusLabel(order.effectiveStatusAt(DateTime.now())),
          ),
          _InfoRow(
            label: 'Người nhận',
            value: recipient.isEmpty ? 'Chưa có thông tin' : recipient,
          ),
          _InfoRow(label: 'Điểm lấy', value: order.pickupAddress),
          _InfoRow(label: 'Điểm giao', value: order.deliveryAddress),
          OrderCargoInfoBlock(
            order: order,
            compact: true,
            showEmptyState: true,
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(
            label: 'Dịch vụ',
            value: _serviceTypeLabel(order.serviceType),
          ),
          _InfoRow(
            label: 'Thanh toán',
            value: _paymentMethodLabel(order.paymentMethod),
          ),
          _InfoRow(label: 'Phí giao', value: _priceText(order), isLast: true),
          const SizedBox(height: AppSpacing.md),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: AppSpacing.md),
          CustomerTrackingRiskAction(order: order),
        ],
      ),
    );
  }
}
