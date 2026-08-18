import 'order_model.dart';

Map<String, dynamic> buildOrderSubmissionPayload(OrderModel order) {
  return {
    'pickup_address': order.pickupAddress,
    'pickup_lat': order.pickupLat,
    'pickup_lng': order.pickupLng,
    'delivery_address': order.deliveryAddress,
    'delivery_lat': order.deliveryLat,
    'delivery_lng': order.deliveryLng,
    'note': order.note,
    'estimated_pickup_at': order.estimatedPickupAt?.toUtc().toIso8601String(),
    'estimated_delivery_at': order.estimatedDeliveryAt
        ?.toUtc()
        .toIso8601String(),
    'recipient_name': order.recipientName,
    'recipient_phone': order.recipientPhone,
    'delivery_fee': order.deliveryFee,
    'service_type': order.serviceType,
    'item_name': order.itemName,
    'item_category': order.itemCategory,
    'item_description': order.itemDescription,
    'item_image_url': order.itemImageUrl,
    'goods_value': order.goodsValue,
    'cod_collection_amount': order.codCollectionAmount,
    'delivery_fee_payer': order.deliveryFeePayer.databaseValue,
  };
}
