import 'order_model.dart';

Map<String, dynamic> buildOrderSubmissionPayload(OrderModel order) {
  return {
    if (order.quotedDistanceMeters != null)
      'quoted_distance_m': order.quotedDistanceMeters,
    if (order.settingsRevision != null)
      'settings_revision': order.settingsRevision,
    'pickup_address': order.pickupAddress,
    'pickup_lat': order.pickupLat,
    'pickup_lng': order.pickupLng,
    'delivery_address': order.deliveryAddress,
    'delivery_lat': order.deliveryLat,
    'delivery_lng': order.deliveryLng,
    'note': order.note,
    if (order.trafficDemoKey != null) 'traffic_demo_key': order.trafficDemoKey,
    'estimated_pickup_at': order.estimatedPickupAt?.toUtc().toIso8601String(),
    'estimated_delivery_at': order.estimatedDeliveryAt
        ?.toUtc()
        .toIso8601String(),
    'recipient_name': order.recipientName,
    'recipient_phone': order.recipientPhone,
    'delivery_fee': order.deliveryFee,
    'quoted_customer_fee': order.customerPlatformFeeAmount,
    'service_type': order.serviceType,
    'item_name': order.itemName,
    'item_category': order.itemCategory,
    'item_description': order.itemDescription,
    'item_image_url': order.itemImageUrl,
    if (order.itemWeightKg != null) 'item_weight_kg': order.itemWeightKg,
    'goods_value': order.goodsValue,
    'cod_collection_amount': order.codCollectionAmount,
    'delivery_fee_payer': order.deliveryFeePayer.databaseValue,
  };
}
