class SavedAddressModel {
  const SavedAddressModel({
    required this.id,
    required this.userId,
    required this.label,
    this.contactName,
    this.contactPhone,
    required this.addressLine,
    required this.lat,
    required this.lng,
    required this.isDefaultPickup,
    required this.isDefaultDelivery,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String label;
  final String? contactName;
  final String? contactPhone;
  final String addressLine;
  final double lat;
  final double lng;
  final bool isDefaultPickup;
  final bool isDefaultDelivery;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SavedAddressModel.fromJson(Map<String, dynamic> json) {
    return SavedAddressModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      contactName: json['contact_name']?.toString(),
      contactPhone: json['contact_phone']?.toString(),
      addressLine: json['address_line']?.toString() ?? '',
      lat: _parseDouble(json['lat']) ?? 0,
      lng: _parseDouble(json['lng']) ?? 0,
      isDefaultPickup: json['is_default_pickup'] as bool? ?? false,
      isDefaultDelivery: json['is_default_delivery'] as bool? ?? false,
      createdAt:
          _parseDateTime(json['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _parseDateTime(json['updated_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'label': label,
      'contact_name': contactName,
      'contact_phone': contactPhone,
      'address_line': addressLine,
      'lat': lat,
      'lng': lng,
      'is_default_pickup': isDefaultPickup,
      'is_default_delivery': isDefaultDelivery,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}