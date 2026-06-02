import '../models/order_model.dart';

const cargoCategories = [
  'food',
  'document',
  'parcel',
  'fragile',
  'grocery',
  'other',
];

String cargoCategoryLabel(String? value) {
  return switch (value) {
    'food' => 'Đồ ăn',
    'document' => 'Tài liệu',
    'parcel' => 'Bưu kiện',
    'fragile' => 'Dễ vỡ',
    'grocery' => 'Tạp hoá',
    'other' => 'Khác',
    _ => 'Chưa phân loại',
  };
}

bool hasCargoInfo(OrderModel order) {
  return [
    order.itemName,
    order.itemCategory,
    order.itemDescription,
    order.itemImageUrl,
  ].any((value) => (value ?? '').trim().isNotEmpty);
}

String cargoNameOrFallback(OrderModel order) {
  final name = order.itemName?.trim();
  return name == null || name.isEmpty ? 'Hàng hoá' : name;
}
