abstract final class CargoPricingText {
  static const packageCount = 'Số kiện hàng';
  static const countError = 'Nhập số kiện từ 1 đến 100.';
  static const size = 'Kích thước khi xếp chung';
  static const sizeHint =
      'Tính cả bao bì. Xếp chung toàn bộ kiện; đối chiếu cạnh dài, vừa, ngắn.';
  static const sizeRequired = 'Vui lòng chọn nhóm kích thước.';
  static const oversized = 'Vượt kích thước trên';
  static const oversizedError = 'Hàng vượt kích thước nhận vận chuyển.';
  static const surcharge = 'Phụ phí hàng';
  static const preliminary =
      'Cước theo quãng đường; phụ phí hàng được cập nhật sau khi khai báo.';
  static const bySize = 'Áp dụng theo kích thước đã chọn.';
  static String byWeight(String weight) =>
      'Áp dụng theo tổng cân nặng $weight.';
  static String weightLimit(num kg) => 'Tổng cân nặng tối đa $kg kg.';
  static String sizeLimit(String dimensions) => 'Tối đa $dimensions';
  static String included(String fee) => 'Đã gồm phụ phí hàng: $fee';
}
