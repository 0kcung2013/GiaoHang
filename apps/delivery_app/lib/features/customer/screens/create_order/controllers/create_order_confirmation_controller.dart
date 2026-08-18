import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/models/order_finance.dart';
import '../../../../../core/utils/delivery_fee_calculator.dart';
import '../utils/order_form_data.dart';
import '../utils/sender_contact_loader.dart';

class CreateOrderPreparationException implements Exception {
  const CreateOrderPreparationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CreateOrderConfirmationController {
  const CreateOrderConfirmationController(this.ref);

  final WidgetRef ref;

  Future<OrderFormData> prepare({
    required String pickupAddress,
    required String pickupFormattedAddress,
    required String pickupAddressDetail,
    required String pickupDeliveryNote,
    required double pickupLat,
    required double pickupLng,
    required String deliveryAddress,
    required String deliveryFormattedAddress,
    required String deliveryAddressDetail,
    required String deliveryDeliveryNote,
    required double deliveryLat,
    required double deliveryLng,
    required String recipientName,
    required String recipientPhone,
    required String note,
    required String itemName,
    required String itemCategory,
    required String itemDescription,
    required XFile? cargoImage,
    required int codCollectionAmount,
    required DeliveryFeeEstimate quote,
  }) async {
    late final SenderContactData sender;
    try {
      sender = await loadSenderContact(ref);
    } on SenderContactException catch (error) {
      throw CreateOrderPreparationException(error.message);
    }

    return OrderFormData(
      pickupAddress: pickupAddress,
      pickupFormattedAddress: pickupFormattedAddress,
      pickupAddressDetail: pickupAddressDetail,
      pickupDeliveryNote: pickupDeliveryNote,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      deliveryAddress: deliveryAddress,
      deliveryFormattedAddress: deliveryFormattedAddress,
      deliveryAddressDetail: deliveryAddressDetail,
      deliveryDeliveryNote: deliveryDeliveryNote,
      deliveryLat: deliveryLat,
      deliveryLng: deliveryLng,
      senderName: sender.name,
      senderPhone: sender.phone,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      note: note,
      itemName: itemName,
      itemCategory: itemCategory,
      itemDescription: itemDescription,
      cargoImage: cargoImage,
      paymentMethod: 'cash',
      deliveryFeePayer: DeliveryFeePayer.recipient,
      goodsValue: 0,
      codCollectionAmount: codCollectionAmount,
      deliveryFee: quote.deliveryFee,
      totalPrice: codCollectionAmount + quote.deliveryFee,
      distanceMeters: quote.distanceMeters,
      durationSeconds: quote.durationSeconds,
      distanceSource: quote.source,
      feeBreakdown: quote.feeBreakdown,
      deliveryEta: quote.eta,
    );
  }
}
