import 'package:image_picker/image_picker.dart';

import '../../../../../core/utils/delivery_eta_calculator.dart';
import '../../../../../core/utils/delivery_pricing_policy.dart';

class OrderFormData {
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String deliveryAddress;
  final double deliveryLat;
  final double deliveryLng;
  final String senderName;
  final String senderPhone;
  final String recipientName;
  final String recipientPhone;
  final String note;
  final String itemName;
  final String itemCategory;
  final String itemDescription;
  final XFile? cargoImage;
  final String paymentMethod;
  final double deliveryFee;
  final double totalPrice;
  final double distanceMeters;
  final double? durationSeconds;
  final String distanceSource;
  final DeliveryFeeBreakdown feeBreakdown;
  final DeliveryEtaEstimate deliveryEta;

  const OrderFormData({
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.deliveryAddress,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.senderName,
    required this.senderPhone,
    required this.recipientName,
    required this.recipientPhone,
    required this.note,
    required this.itemName,
    required this.itemCategory,
    required this.itemDescription,
    required this.cargoImage,
    required this.paymentMethod,
    required this.deliveryFee,
    required this.totalPrice,
    required this.distanceMeters,
    this.durationSeconds,
    this.distanceSource = 'haversine',
    required this.feeBreakdown,
    required this.deliveryEta,
  });

  double get distanceKm => distanceMeters / 1000;
}
