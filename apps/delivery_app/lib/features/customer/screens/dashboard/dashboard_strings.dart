abstract final class DashboardStrings {
  static const heroTitle = 'Cần giao hàng?';
  static const createDelivery = 'Đặt ngay';
  static const pickupPrompt = 'Điểm lấy hàng';
  static const deliveryPrompt = 'Giao đến đâu?';
  static const courierIllustrationAsset =
      'assets/images/customer_home_courier_v2.png';
  static const courierIllustrationSemantics =
      'Nhân viên giao hàng cầm bưu kiện bên cạnh xe máy';
  static const createOrder = 'Tạo đơn';
  static const trackOrder = 'Theo dõi';
  static const orderHistory = 'Đơn hàng';
  static const liveBadge = 'LIVE';
  static const servicePromiseTitle = 'An tâm trên mọi hành trình';
  static const transparentPrice = 'Phí minh bạch';
  static const verifiedDriver = 'Tài xế xác thực';
  static const liveTracking = 'Theo dõi trực tiếp';
  static const customerFallback = 'bạn';
  static const customerInitials = 'KH';

  static String createDeliverySemantics({required bool isFirstDelivery}) {
    return isFirstDelivery
        ? 'Tạo chuyến giao hàng đầu tiên'
        : 'Tạo chuyến giao hàng mới';
  }

  static String avatarSemantics(String name) {
    return 'Ảnh đại diện $name';
  }
}
