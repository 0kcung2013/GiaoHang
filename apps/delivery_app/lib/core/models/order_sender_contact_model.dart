class OrderSenderContactModel {
  const OrderSenderContactModel({required this.name, required this.phone});

  final String name;
  final String phone;

  factory OrderSenderContactModel.fromJson(Map<String, dynamic> json) {
    return OrderSenderContactModel(
      name: json['contact_name']?.toString().trim() ?? '',
      phone: json['contact_phone']?.toString().trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'contact_name': name,
    'contact_phone': phone,
  };
}
