class OrderItemModel {
  const OrderItemModel({
    required this.id,
    required this.orderId,
    required this.name,
    required this.quantity,
    required this.price,
  });

  final String id;
  final String orderId;
  final String name;
  final int quantity;
  final double price;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      quantity: _parseInt(json['quantity']) ?? 0,
      price: _parseDouble(json['price']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'name': name,
      'quantity': quantity,
      'price': price,
    };
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}