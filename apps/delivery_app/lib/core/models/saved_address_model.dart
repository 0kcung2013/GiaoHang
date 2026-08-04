enum SavedAddressLabelType {
  home('home'),
  work('work'),
  warehouse('warehouse'),
  other('other');

  const SavedAddressLabelType(this.databaseValue);

  final String databaseValue;

  static SavedAddressLabelType fromDatabase(dynamic value) {
    return SavedAddressLabelType.values.firstWhere(
      (type) => type.databaseValue == value?.toString(),
      orElse: () => SavedAddressLabelType.other,
    );
  }
}

class SavedAddressModel {
  const SavedAddressModel({
    required this.id,
    required this.userId,
    required this.labelType,
    this.customLabel,
    required this.formattedAddress,
    required this.addressDetail,
    required this.deliveryNote,
    required this.latitude,
    required this.longitude,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final SavedAddressLabelType labelType;
  final String? customLabel;
  final String formattedAddress;
  final String addressDetail;
  final String deliveryNote;
  final double latitude;
  final double longitude;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get fullAddress {
    final detail = addressDetail.trim();
    if (detail.isEmpty) return formattedAddress.trim();
    if (formattedAddress.toLowerCase().startsWith(detail.toLowerCase())) {
      return formattedAddress.trim();
    }
    return '$detail, ${formattedAddress.trim()}';
  }

  factory SavedAddressModel.fromJson(Map<String, dynamic> json) {
    return SavedAddressModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      labelType: SavedAddressLabelType.fromDatabase(json['label_type']),
      customLabel: _optionalText(json['custom_label']),
      formattedAddress: json['formatted_address']?.toString() ?? '',
      addressDetail: json['address_detail']?.toString() ?? '',
      deliveryNote: json['delivery_note']?.toString() ?? '',
      latitude: _parseDouble(json['latitude']) ?? 0,
      longitude: _parseDouble(json['longitude']) ?? 0,
      isDefault: json['is_default'] as bool? ?? false,
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
      'label_type': labelType.databaseValue,
      'custom_label': customLabel,
      'formatted_address': formattedAddress,
      'address_detail': addressDetail,
      'delivery_note': deliveryNote,
      'latitude': latitude,
      'longitude': longitude,
      'is_default': isDefault,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toMutationJson() {
    return {
      'user_id': userId,
      'label_type': labelType.databaseValue,
      'custom_label': labelType == SavedAddressLabelType.other
          ? customLabel?.trim()
          : null,
      'formatted_address': formattedAddress.trim(),
      'address_detail': addressDetail.trim(),
      'delivery_note': deliveryNote.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'is_default': isDefault,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  SavedAddressModel copyWith({
    String? id,
    String? userId,
    SavedAddressLabelType? labelType,
    String? customLabel,
    bool clearCustomLabel = false,
    String? formattedAddress,
    String? addressDetail,
    String? deliveryNote,
    double? latitude,
    double? longitude,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedAddressModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      labelType: labelType ?? this.labelType,
      customLabel: clearCustomLabel ? null : customLabel ?? this.customLabel,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      addressDetail: addressDetail ?? this.addressDetail,
      deliveryNote: deliveryNote ?? this.deliveryNote,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

String? _optionalText(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
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
