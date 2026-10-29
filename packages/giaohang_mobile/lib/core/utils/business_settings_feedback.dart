abstract final class BusinessSettingsFeedback {
  static String? forError(Object error) {
    final text = error.toString();
    if (text.contains('SETTINGS_QUOTE_')) {
      return 'Giá cước đã thay đổi. Vui lòng quay lại bước báo giá để tính lại trước khi đặt đơn.';
    }
    if (text.contains('ORDER_PRICE_INVALID') ||
        text.contains('PAID_GOODS_VALUE_REQUIRED')) {
      return 'Giá trị hàng hoặc COD vượt hạn mức hiện tại. Vui lòng quay lại kiểm tra thông tin thanh toán.';
    }
    return null;
  }
}
