import '../../../../../core/models/order_finance.dart';
import '../../../../../core/models/order_model.dart';
import 'order_form_data.dart';

OrderModel buildOrderFromForm({
  required OrderFormData data,
  required String customerId,
  required DateTime now,
  String? itemImageUrl,
}) => OrderModel(
  id: '',
  customerId: customerId,
  status: 'pending',
  pickupAddress: data.pickupAddress.trim(),
  pickupLat: data.pickupLat,
  pickupLng: data.pickupLng,
  deliveryAddress: data.deliveryAddress.trim(),
  deliveryLat: data.deliveryLat,
  deliveryLng: data.deliveryLng,
  totalPrice: data.finance.totalPrice.toDouble(),
  note: data.combinedDriverNote.isEmpty ? null : data.combinedDriverNote,
  createdAt: now,
  trackingCode: '',
  recipientName: data.recipientName.trim(),
  recipientPhone: data.recipientPhone.trim(),
  itemName: data.itemName.trim(),
  itemCategory: data.itemCategory,
  itemDescription: data.itemDescription.trim().isEmpty
      ? null
      : data.itemDescription.trim(),
  itemImageUrl: itemImageUrl,
  deliveryFee: data.deliveryFee,
  serviceType: 'standard',
  paymentMethod: data.paymentMethod,
  paymentMode: data.paymentMode,
  deliveryFeePayer: data.deliveryFeePayer,
  paymentStatus: data.deliveryFeePayer == DeliveryFeePayer.sender
      ? OrderPaymentStatus.pending
      : OrderPaymentStatus.notRequired,
  goodsValue: data.goodsValue,
  codCollectionAmount: data.codCollectionAmount,
  platformFeeRateBps: 0,
  platformFeeAmount: 0,
  driverNetEarning: data.finance.driverNetEarning,
  driverAdvanceAmount: data.finance.driverAdvanceAmount,
  receiverCollectionAmount: data.finance.receiverCollectionAmount,
  updatedAt: now,
);
