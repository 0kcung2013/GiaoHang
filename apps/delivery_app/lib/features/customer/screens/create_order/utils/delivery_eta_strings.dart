class DeliveryEtaStrings {
  DeliveryEtaStrings._();

  static const estimatedDelivery = 'Dự kiến giao';
  static const afterAssignment = 'ETA cập nhật khi tài xế nhận đơn';
  static const waitingForDriver = 'Chưa có tài xế';
  static const detailTitle = 'Chi tiết thời gian';
  static const historicalTraffic = 'AI · dữ liệu giao thông mô phỏng';
  static const routeEstimate = 'Ước tính theo tuyến đường';
  static const travelLabel = 'Di chuyển dự kiến';
  static const handlingLabel = 'Bàn giao dự kiến';
  static const fromPickup = 'Từ khi tài xế lấy hàng';
  static const rangeExplanation =
      'Thời gian dự kiến được làm tròn từ vận tốc AI và thời gian bàn giao.';
  static const detailsSemantics = 'Chi tiết thời gian giao hàng dự kiến';
  static const expandDetails = 'Chạm để xem chi tiết';
  static const collapseDetails = 'Chạm để thu gọn';
  static const peakHour = 'Giờ cao điểm';

  static String travelMinutes(double minutes) =>
      'Khoảng ${minutes.round()} phút';

  static String handlingMinutes(int minutes) => '$minutes phút';

  static String pickupWithHandling(int minutes) =>
      '$fromPickup · gồm $minutes phút bàn giao';
}
