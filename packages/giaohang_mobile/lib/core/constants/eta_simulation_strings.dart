class EtaSimulationStrings {
  EtaSimulationStrings._();
  static const datasetLabel = 'AI · ETA mô phỏng TP.HCM';
  static const datasetScope =
      'LightGBM dự đoán tốc độ từng đoạn từ dữ liệu giao thông mô phỏng';
  static const legendTitle = 'Tốc độ AI dự đoán · km/h';
  static const clear = 'Nhanh ≥35';
  static const moderate = 'Vừa 25–<35';
  static const heavy = 'Chậm 20–<25';
  static const congested = 'Chậm hơn 15–<20';
  static const legacyLegendTitle = 'Giao thông mô phỏng';
  static const legacyClear = 'Thoáng <25%';
  static const legacyModerate = 'Chậm nhẹ 25–<50%';
  static const legacyHeavy = 'Đông 50–<75%';
  static const legacyCongested = 'Rất đông ≥75%';
  static const legacyLegendSemantics =
      'Mức chậm thêm mô phỏng: xanh dưới 25%, vàng 25 đến dưới 50%, cam 50 đến dưới 75%, đỏ từ 75%';
  static const unavailable = 'Chưa có dự báo';
  static const outsideCoverage = 'Ngoài vùng dự đoán AI · ETA từ OSRM';
  static const routingEstimate = 'Chưa có dự đoán AI · ETA từ OSRM';
  static const unlocalized = 'Chưa xác định mức chậm từng đoạn';
  static const legendSemantics =
      'Tốc độ AI dự đoán theo km trên giờ: xanh từ 35, vàng từ 25 đến dưới 35, cam từ 20 đến dưới 25, đỏ từ 15 đến dưới 20';
}
