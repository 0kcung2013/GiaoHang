import 'package:latlong2/latlong.dart';

class TrafficDemoScenario {
  const TrafficDemoScenario({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.pickupAddress,
    required this.pickup,
    required this.deliveryAddress,
    required this.delivery,
  });

  final String id;
  final String title;
  final String subtitle;
  final String pickupAddress;
  final LatLng pickup;
  final String deliveryAddress;
  final LatLng delivery;

  static const hcmHistoricCongestion = TrafficDemoScenario(
    id: 'hcm_tran_quoc_thao_historic_congestion',
    title: 'Ùn tắc',
    subtitle: 'Tuyến AI lịch sử',
    pickupAddress: 'Khu vực đầu tuyến trung tâm TP.HCM',
    pickup: LatLng(10.786000, 106.678950),
    deliveryAddress: 'Khu vực cuối tuyến trung tâm, TP.HCM',
    delivery: LatLng(10.821000, 106.678950),
  );

  static const hcmHistoricClearTraffic = TrafficDemoScenario(
    id: 'hcm_central_historic_clear_traffic',
    title: 'Thông thoáng',
    subtitle: 'Tuyến đối chứng',
    pickupAddress: 'Đầu tuyến đối chứng trung tâm, TP.HCM',
    pickup: LatLng(10.776000, 106.687000),
    deliveryAddress: 'Cuối tuyến đối chứng trung tâm, TP.HCM',
    delivery: LatLng(10.807000, 106.709000),
  );
}
