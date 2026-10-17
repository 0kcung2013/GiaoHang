class DeliveryEtaStrings {
  DeliveryEtaStrings._();

  static const estimatedDelivery = 'Dự kiến giao';
  static const afterAssignment = 'ETA cập nhật khi tài xế nhận đơn';
  static const waitingForDriver = 'Chưa có tài xế';
  static const detailTitle = 'Chi tiết thời gian';
  static const historicalTraffic = 'AI · ETA giao thông mô phỏng';
  static const simulatedTraffic = 'AI dự đoán tốc độ';
  static const distanceLabel = 'Quãng đường';
  static const averageSpeedLabel = 'Tốc độ trung bình';
  static String distance(double meters) =>
      '${(meters / 1000).toStringAsFixed(2).replaceAll('.', ',')} km';
  static String averageSpeed(double speed) =>
      '${speed.toStringAsFixed(1).replaceAll('.', ',')} km/h';
  static const legacySimulatedTraffic = 'ETA theo tốc độ giao thông mô phỏng';
  static const lightgbmComparison = 'LightGBM đối chiếu · di chuyển';
  static const routeEstimate = 'Ước tính theo tuyến đường';
  static const travelLabel = 'Di chuyển dự kiến';
  static const handlingLabel = 'Bàn giao dự kiến';
  static const fromPickup = 'Từ khi tài xế lấy hàng';
  static const rangeExplanation =
      'Thời gian dự kiến gồm thời gian di chuyển và bàn giao.';
  static const aiRangeExplanation =
      'Di chuyển = quãng đường ÷ tốc độ trung bình. Bàn giao tính riêng.';
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
