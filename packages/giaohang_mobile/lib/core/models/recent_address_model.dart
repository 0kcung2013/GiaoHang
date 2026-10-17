enum RecentAddressType {
  pickup('pickup'),
  delivery('delivery');

  const RecentAddressType(this.databaseValue);

  final String databaseValue;

  static RecentAddressType fromDatabase(dynamic value) {
    return value?.toString() == pickup.databaseValue ? pickup : delivery;
  }
}

class RecentAddressModel {
  const RecentAddressModel({
    required this.id,
    required this.userId,
    required this.addressType,
    required this.formattedAddress,
    required this.addressDetail,
    required this.deliveryNote,
    required this.latitude,
    required this.longitude,
    required this.usageCount,
    required this.lastUsedAt,
  });

  final String id;
  final String userId;
  final RecentAddressType addressType;
  final String formattedAddress;
  final String addressDetail;
  final String deliveryNote;
  final double latitude;
  final double longitude;
  final int usageCount;
  final DateTime lastUsedAt;

  String get fullAddress {
    final detail = addressDetail.trim();
    if (detail.isEmpty) return formattedAddress.trim();
    if (formattedAddress.toLowerCase().startsWith(detail.toLowerCase())) {
      return formattedAddress.trim();
    }
    return '$detail, ${formattedAddress.trim()}';
  }

  factory RecentAddressModel.fromJson(Map<String, dynamic> json) {
    return RecentAddressModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      addressType: RecentAddressType.fromDatabase(json['address_type']),
      formattedAddress: json['formatted_address']?.toString() ?? '',
      addressDetail: json['address_detail']?.toString() ?? '',
      deliveryNote: json['delivery_note']?.toString() ?? '',
      latitude: _parseDouble(json['latitude']) ?? 0,
      longitude: _parseDouble(json['longitude']) ?? 0,
      usageCount: _parseInt(json['usage_count']) ?? 1,
      lastUsedAt:
          _parseDateTime(json['last_used_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'address_type': addressType.databaseValue,
      'formatted_address': formattedAddress,
      'address_detail': addressDetail,
      'delivery_note': deliveryNote,
      'latitude': latitude,
      'longitude': longitude,
      'usage_count': usageCount,
      'last_used_at': lastUsedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toRecordJson() {
    return {
      'address_type': addressType.databaseValue,
      'formatted_address': formattedAddress.trim(),
      'address_detail': addressDetail.trim(),
      'delivery_note': deliveryNote.trim(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
