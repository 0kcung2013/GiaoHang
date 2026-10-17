abstract final class OrderDetailStrings {
  static const screenTitle = 'Chi tiết đơn hàng';
  static const cargoTitle = 'Kiện hàng';
  static const routeTitle = 'Lộ trình giao hàng';
  static const paymentTitle = 'Dịch vụ & thanh toán';
  static const itemsTitle = 'Danh sách hàng hóa';
  static const timelineTitle = 'Hành trình đơn hàng';
  static const noteTitle = 'Ghi chú cho tài xế';
  static const cancelTitle = 'Hủy đơn hàng';
  static const trackAction = 'Theo dõi đơn';

  static const pickup = 'Điểm lấy hàng';
  static const delivery = 'Điểm giao hàng';
  static const recipient = 'Người nhận';
  static const phone = 'Điện thoại';
  static const service = 'Dịch vụ';
  static const payment = 'Thanh toán';
  static const deliveryFee = 'Phí giao hàng';
  static const total = 'Tổng thanh toán';

  static const noData = 'Chưa cập nhật';
  static const noFee = 'Chưa tính phí';
  static const cargoFallback = 'Hàng hóa';
  static const noItems = 'Chưa có hàng hóa.';
  static const itemsLoadError = 'Không tải được hàng hóa.';
  static const itemsLoading = 'Đang tải hàng hóa...';
  static const timelineLoading = 'Đang tải hành trình...';

  static const cancelDescription =
      'Bạn có thể hủy đơn trước khi quá trình giao hàng bắt đầu.';
  static const riskyCancelDescription =
      'Tài xế đang xử lý đơn. Việc hủy lúc này có thể ảnh hưởng đến quá trình giao hàng.';
  static const cancelLockedDescription =
      'Không thể hủy vì tài xế đã nhận hàng và đang giao đến người nhận.';
  static const cancelPickupLockedDescription =
      'Tài xế đã xác nhận nhận hàng. Vui lòng liên hệ CSKH nếu cần hỗ trợ.';
  static const cancelReasonHint = 'Nhập lý do hủy đơn';
  static const cancelAction = 'Hủy đơn hàng';
  static const cancelLockedAction = 'Không thể hủy đơn';
  static const confirmCancelAction = 'Xác nhận hủy đơn';
  static const cancellingAction = 'Đang hủy...';
  static const cancelReasonRequired = 'Vui lòng nhập lý do hủy đơn.';
  static const cancelledSuccess = 'Đã hủy đơn hàng.';
  static const cancelFailure = 'Không thể hủy đơn. Vui lòng thử lại.';
  static const cancelInProgressFailure =
      'Không thể hủy: tài xế đang lấy hoặc giao hàng.';
  static const cancelSessionFailure =
      'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.';
  static const cancelOwnershipFailure = 'Bạn không có quyền hủy đơn hàng này.';
  static const cancelNotFoundFailure = 'Không tìm thấy đơn hàng để hủy.';
  static const cancelBackendUnavailableFailure =
      'Tính năng hủy đơn chưa sẵn sàng trên hệ thống. Vui lòng liên hệ CSKH.';

  static String cancellationFailureMessage(Object error) {
    final details = error.toString();
    if (details.contains('ORDER_ALREADY_PICKED_UP') ||
        details.contains('ORDER_NOT_CANCELLABLE')) {
      return cancelInProgressFailure;
    }
    if (details.contains('AUTH_REQUIRED') ||
        details.contains('CUSTOMER_ROLE_REQUIRED') ||
        details.contains('42501')) {
      return cancelSessionFailure;
    }
    if (details.contains('CUSTOMER_ID_MISMATCH') ||
        details.contains('ORDER_NOT_OWNED')) {
      return cancelOwnershipFailure;
    }
    if (details.contains('ORDER_NOT_FOUND')) return cancelNotFoundFailure;
    if (details.contains('23505')) {
      return 'Đơn đã được xử lý hủy hoặc giao dịch hoàn tiền đã tồn tại. Vui lòng tải lại danh sách đơn.';
    }
    if (details.contains('23502') || details.contains('23503')) {
      return 'Dữ liệu tài chính của đơn chưa đầy đủ để hủy. Vui lòng liên hệ CSKH.';
    }
    if (details.contains('42703') || details.contains('42883')) {
      return cancelBackendUnavailableFailure;
    }
    if (details.contains('PGRST202') ||
        details.contains('cancel_customer_order')) {
      return cancelBackendUnavailableFailure;
    }
    final code = RegExp(
      r'(?:code|SQLSTATE)[:=]\s*([A-Z0-9]+)',
      caseSensitive: false,
    ).firstMatch(details)?.group(1);
    if (code != null && code.isNotEmpty) {
      return 'Không thể hủy đơn (mã lỗi $code). Vui lòng liên hệ CSKH.';
    }
    return cancelFailure;
  }
}
