import 'package:flutter/material.dart';

enum AdminSection {
  overview('overview', 'Tổng quan', Icons.space_dashboard_rounded, 'Điều hành'),
  drivers('drivers', 'Phê duyệt tài xế', Icons.badge_rounded, 'Cần Admin'),
  accounts('accounts', 'Người dùng', Icons.people_alt_rounded, 'Quản trị'),
  configuration(
    'configuration',
    'Cấu hình hệ thống',
    Icons.tune_rounded,
    'Quản trị',
  ),
  orders('orders', 'Đơn hàng', Icons.inventory_2_rounded, 'Tra cứu vận hành'),
  monitoring(
    'monitoring',
    'Sự cố giao hàng',
    Icons.radar_rounded,
    'Tra cứu vận hành',
  ),
  journeys('journeys', 'Hành trình', Icons.route_rounded, 'Tra cứu vận hành'),
  transactions(
    'transactions',
    'Nạp tiền & thanh toán',
    Icons.account_balance_wallet_rounded,
    'Tra cứu vận hành',
  ),
  settings('settings', 'Tài khoản quản trị', Icons.tune_rounded, 'Quản trị');

  const AdminSection(this.slug, this.label, this.icon, this.group);
  final String slug;
  final String label;
  final IconData icon;
  final String group;

  static const primary = [overview, drivers, accounts, configuration];
  static const lookups = [orders, monitoring, journeys, transactions];
  bool get isLookup => lookups.contains(this);

  String get route => '/admin-home?section=$slug';
  static AdminSection parse(String? value) =>
      values.firstWhere((s) => s.slug == value, orElse: () => overview);
}
