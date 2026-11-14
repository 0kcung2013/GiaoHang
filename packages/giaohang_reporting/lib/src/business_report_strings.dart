abstract final class BusinessReportStrings {
  static const title = 'Bảng kê';
  static const statementTitle = 'Bảng kê đối soát';
  static const export = 'Tải bảng kê';
  static const exporting = 'Đang tạo file…';
  static const excel = 'Excel (.xlsx)';
  static const pdf = 'PDF (.pdf)';
  static const error = 'Không tải được báo cáo. Vui lòng thử lại.';
  static const tooLarge =
      'Kỳ có hơn 5.000 dòng. Hãy chọn khoảng ngày ngắn hơn.';
  static const unavailable = 'Báo cáo chưa được thiết lập trên máy chủ.';
  static const forbidden =
      'Tài khoản không có quyền xem báo cáo doanh nghiệp này.';
  static const exportError = 'Chưa xuất được file. Vui lòng thử lại.';
  static const retry = 'Thử lại';
  static const refresh = 'Tải lại';
  static const period = 'Chọn khoảng ngày';
  static const cancel = 'Hủy';
  static const choose = 'Chọn';
  static const maxRange = 'Chọn tối đa 366 ngày.';
  static const previousMonth = 'Tháng trước';
  static const nextMonth = 'Tháng sau';
  static const empty = 'Chưa có dữ liệu trong kỳ này';
  static const orders = 'Đơn hàng';
  static const movements = 'Giao dịch tiền';
  static const deliveredCod = 'COD đơn giao thành công';
  static const codCredits = 'COD ghi có vào ví trong kỳ';
  static const senderCharges = 'Chi phí người gửi chịu';
  static const recipientCharges = 'Cước và phí người nhận chịu';
  static const refunds = 'Hoàn phí vào ví trong kỳ';
  static const scope =
      'Bảng kê dữ liệu GiaoHang, không thay thế hóa đơn hoặc tờ khai thuế.';
  static const dateBasis =
      'Giao nhận theo ngày giao/hoàn/hủy; dòng tiền theo ngày giao dịch (UTC+7).';
  static const costBasis =
      'Phí theo đơn là mức đã chốt. Đơn hủy không tính chi phí; đơn hoàn được miễn/hoàn phí sàn.';
  static const codBasis =
      'COD ghi có vào ví có thể phát sinh trước khi giao hàng. Không cộng hai chỉ tiêu COD thành doanh thu.';
  static const serviceExpense = 'Chi phí bạn chịu';
  static const staffServiceExpense = 'Chi phí người gửi chịu';
  static const deliveredCodShort = 'COD từ đơn đã giao';
  static const codCreditsShort = 'COD đã ghi có vào ví';
  static const guide = 'Cách đọc số liệu';
  static const guideCod = 'Tiền hàng COD';
  static const guideCosts = 'Chi phí dịch vụ';
  static const guideDates = 'Kỳ đối soát';
  static const guideScope = 'Hỗ trợ kế toán, thuế';
  static const close = 'Đóng';
  static const statementProfile = 'Thông tin trên bảng kê';
  static const excelHint = 'Dùng để tổng hợp, tính toán';
  static const pdfHint = 'Dùng để xem, in và lưu trữ';
  static const exportScope =
      'Bảng kê không thay thế hóa đơn hoặc tờ khai thuế.';
  static const refundShort = 'Hoàn phí vào ví';
  static const expenseShort = 'Bạn chịu';
  static const noLinkedOrder = 'Giao dịch không gắn đơn';
  static String month(int month, int year) => 'Tháng $month/$year';
  static const currentProfile = 'Hồ sơ kinh doanh hiện tại · Thông tin tự khai';
  static const profileHint =
      'Thông tin này không xác nhận danh tính bên mua tại thời điểm giao dịch.';
  static const missing = 'Chưa cung cấp';
  static const taxCode = 'Mã số thuế';
  static const generated = 'Dữ liệu chốt lúc';
  static const currency = 'Đơn vị: VND';
  static const more = 'Xem thêm';
  static const code = 'Mã đơn';
  static const date = 'Ngày (UTC+7)';
  static const status = 'Trạng thái';
  static const cod = 'COD';
  static const deliveryFee = 'Cước gốc';
  static const platformFee = 'Phí sàn theo đơn';
  static const returnFee = 'Phí hoàn đã quyết toán';
  static const kind = 'Loại giao dịch';
  static const reference = 'Mã giao dịch';
  static const amount = 'Số tiền';
  static const state = 'Trạng thái thanh toán';
  static const sender = 'Người gửi';
  static const recipient = 'Người nhận';
  static const feePayer = 'Bên chịu cước';
  static String orderStatus(String value) => switch (value) {
    'delivered' => 'Đã giao',
    'returned' => 'Đã hoàn hàng',
    'cancelled' => 'Đã hủy',
    _ => value,
  };
  static String movement(String value) => switch (value) {
    'delivery_credit' => 'COD ghi có vào ví',
    'failed_delivery_credit' => 'Bồi hoàn giao thất bại',
    'risk_credit' => 'Quyết toán rủi ro',
    'adjustment_credit' => 'Điều chỉnh tăng',
    'adjustment_debit' => 'Điều chỉnh giảm',
    'delivery_fee_payment' => 'Thanh toán/giữ phí từ ví',
    'delivery_fee_refund' => 'Hoàn phí vào ví',
    'vnpay_payment' => 'Thanh toán qua VNPAY',
    _ => value,
  };
  static String paymentState(String? value) => switch (value) {
    'paid' || 'settled' => 'Đã thanh toán',
    'reserved' => 'Đang giữ phí',
    'refunded' => 'Đã hoàn vào ví',
    'refund_required' => 'Chờ xử lý hoàn',
    'not_required' => 'Người nhận trả tiền mặt',
    null => 'Đã ghi sổ',
    _ => value,
  };
}
