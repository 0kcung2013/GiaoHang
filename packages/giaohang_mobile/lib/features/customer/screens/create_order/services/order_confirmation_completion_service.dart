import 'package:flutter/foundation.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../../core/models/recent_address_model.dart';
import '../../../../../core/services/customer_order_service.dart';
import '../../../../../core/services/recent_address_service.dart';
import '../utils/order_form_data.dart';

class OrderConfirmationCompletionService {
  const OrderConfirmationCompletionService({
    required this.orderService,
    required this.recentAddressService,
  });

  final CustomerOrderService orderService;
  final RecentAddressService recentAddressService;

  Future<OrderModel> complete({
    required String orderId,
    required String trackingCode,
    required OrderModel fallbackOrder,
    required OrderFormData data,
    required String userId,
    required DateTime addressTimestamp,
  }) async {
    try {
      await recentAddressService.recordOrderAddresses(
        userId: userId,
        pickup: _address(
          userId: userId,
          type: RecentAddressType.pickup,
          formattedAddress: data.pickupFormattedAddress,
          addressDetail: data.pickupAddressDetail,
          deliveryNote: data.pickupDeliveryNote,
          latitude: data.pickupLat,
          longitude: data.pickupLng,
          timestamp: addressTimestamp,
        ),
        delivery: _address(
          userId: userId,
          type: RecentAddressType.delivery,
          formattedAddress: data.deliveryFormattedAddress,
          addressDetail: data.deliveryAddressDetail,
          deliveryNote: data.deliveryDeliveryNote,
          latitude: data.deliveryLat,
          longitude: data.deliveryLng,
          timestamp: addressTimestamp,
        ),
      );
    } catch (error) {
      debugPrint('[RecentAddress] record after order creation failed: $error');
    }

    final full =
        await orderService.getOrderById(orderId) ??
        fallbackOrder.copyWith(id: orderId, trackingCode: trackingCode);
    await orderService.notifyAfterOrderCreated(full);
    return full;
  }

  RecentAddressModel _address({
    required String userId,
    required RecentAddressType type,
    required String formattedAddress,
    required String addressDetail,
    required String deliveryNote,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
  }) => RecentAddressModel(
    id: '',
    userId: userId,
    addressType: type,
    formattedAddress: formattedAddress,
    addressDetail: addressDetail,
    deliveryNote: deliveryNote,
    latitude: latitude,
    longitude: longitude,
    usageCount: 1,
    lastUsedAt: timestamp,
  );
}
