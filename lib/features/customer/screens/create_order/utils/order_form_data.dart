import 'package:image_picker/image_picker.dart';

class OrderFormData {
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String deliveryAddress;
  final double deliveryLat;
  final double deliveryLng;
  final String recipientName;
  final String recipientPhone;
  final String note;
  final String itemName;
  final String itemCategory;
  final String itemDescription;
  final XFile? cargoImage;
  final String serviceType;
  final String paymentMethod;
  final double deliveryFee;
  final double totalPrice;
  final double distanceMeters;
  final double? durationSeconds;
  final String distanceSource;

  const OrderFormData({
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.deliveryAddress,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.recipientName,
    required this.recipientPhone,
    required this.note,
    required this.itemName,
    required this.itemCategory,
    required this.itemDescription,
    required this.cargoImage,
    required this.serviceType,
    required this.paymentMethod,
    required this.deliveryFee,
    required this.totalPrice,
    required this.distanceMeters,
    this.durationSeconds,
    this.distanceSource = 'haversine',
  });

  double get distanceKm => distanceMeters / 1000;
}
