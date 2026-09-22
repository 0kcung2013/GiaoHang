import '../../../../../core/utils/order_cargo_utils.dart';
import 'vietnam_phone_input.dart';

abstract final class OrderFormValidationText {
  static const photoRequired = 'Thêm ảnh kiện hàng.';
  static const categoryRequired = 'Chọn danh mục hàng.';
}

String? validateOrderCategory(String value) => cargoCategories.contains(value)
    ? null
    : OrderFormValidationText.categoryRequired;

String? validateOrderDetails({
  required String recipientName,
  required String recipientPhone,
  required String itemName,
  required String itemCategory,
  required bool hasPhoto,
}) {
  return requiredOrderText('Nhập tên người nhận.')(recipientName) ??
      validateVietnamPhone(recipientPhone) ??
      requiredOrderText('Nhập tên kiện hàng.')(itemName) ??
      validateOrderCategory(itemCategory) ??
      (hasPhoto ? null : OrderFormValidationText.photoRequired);
}

String? Function(String?) requiredOrderText(String message) {
  return (value) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  };
}
