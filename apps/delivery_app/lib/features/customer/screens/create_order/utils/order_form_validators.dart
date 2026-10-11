import '../../../../../core/utils/order_cargo_utils.dart';
import 'vietnam_phone_input.dart';
import 'package:giaohang_domain/giaohang_domain.dart' show isCargoWeightInput;

abstract final class OrderFormValidationText {
  static const photoRequired = 'Thêm ảnh kiện hàng.';
  static const categoryRequired = 'Chọn danh mục hàng.';
  static const weightRequired = 'Nhập khối lượng kiện hàng (kg).';
  static const weightInvalid =
      'Nhập số kg lớn hơn 0, tối đa 3 chữ số thập phân.';
}

String? validateOrderWeight(String? value) {
  if (value == null || value.trim().isEmpty) {
    return OrderFormValidationText.weightRequired;
  }
  return isCargoWeightInput(value)
      ? null
      : OrderFormValidationText.weightInvalid;
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
  String? itemWeight,
}) {
  return requiredOrderText('Nhập tên người nhận.')(recipientName) ??
      validateVietnamPhone(recipientPhone) ??
      requiredOrderText('Nhập tên kiện hàng.')(itemName) ??
      validateOrderCategory(itemCategory) ??
      (itemWeight == null ? null : validateOrderWeight(itemWeight)) ??
      (hasPhoto ? null : OrderFormValidationText.photoRequired);
}

String? Function(String?) requiredOrderText(String message) {
  return (value) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  };
}
