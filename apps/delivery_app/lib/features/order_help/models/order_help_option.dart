import 'package:flutter/material.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

enum OrderHelpChannel { support, risk }

class OrderHelpOption {
  const OrderHelpOption({
    required this.category,
    required this.channel,
    required this.label,
    required this.description,
    required this.icon,
    this.priority = SupportTicketPriority.normal,
  });

  final RiskCategory category;
  final OrderHelpChannel channel;
  final String label;
  final String description;
  final IconData icon;
  final SupportTicketPriority priority;
}

const customerOrderHelpOptions = [
  OrderHelpOption(
    category: RiskCategory.deliveryDelay,
    channel: OrderHelpChannel.support,
    label: 'Giao hàng chậm',
    description: 'Đơn chưa di chuyển hoặc lâu hơn thời gian dự kiến.',
    icon: Icons.schedule_rounded,
  ),
  OrderHelpOption(
    category: RiskCategory.contactIssue,
    channel: OrderHelpChannel.support,
    label: 'Không thể liên lạc',
    description: 'Không gọi hoặc nhắn tin được cho tài xế.',
    icon: Icons.phone_disabled_rounded,
  ),
  OrderHelpOption(
    category: RiskCategory.cargoIssue,
    channel: OrderHelpChannel.support,
    label: 'Hàng hóa có vấn đề',
    description: 'Hàng sai, thiếu, rách hoặc hư hỏng.',
    icon: Icons.inventory_2_outlined,
    priority: SupportTicketPriority.high,
  ),
  OrderHelpOption(
    category: RiskCategory.payment,
    channel: OrderHelpChannel.support,
    label: 'Thanh toán hoặc phí',
    description: 'Khoản thu, phí hoặc phương thức thanh toán chưa đúng.',
    icon: Icons.payments_outlined,
  ),
  OrderHelpOption(
    category: RiskCategory.safety,
    channel: OrderHelpChannel.risk,
    label: 'An toàn hoặc đáng ngờ',
    description: 'Có nguy cơ ảnh hưởng đến người, hàng hóa hoặc tài sản.',
    icon: Icons.health_and_safety_outlined,
    priority: SupportTicketPriority.high,
  ),
  OrderHelpOption(
    category: RiskCategory.other,
    channel: OrderHelpChannel.support,
    label: 'Vấn đề khác',
    description: 'Nội dung chưa phù hợp với các lựa chọn trên.',
    icon: Icons.more_horiz_rounded,
  ),
];
