import 'package:latlong2/latlong.dart';
import '../../../../../core/models/traffic_demo_clock.dart';

class TrafficDemoScenario {
  const TrafficDemoScenario({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.pickupAddress,
    required this.pickup,
    required this.deliveryAddress,
    required this.delivery,
    required this.isCongested,
  });

  final String id;
  final String title;
  final String subtitle;
  final String pickupAddress;
  final LatLng pickup;
  final String deliveryAddress;
  final LatLng delivery;
  final bool isCongested;

  /// Fixed synthetic comparison times; unrelated to the actual assignment clock.
  String get key =>
      isCongested ? TrafficDemoClock.peak : TrafficDemoClock.offPeak;
  DateTime get forecastAt => TrafficDemoClock.forecastAt(key)!;

  static const hcmHistoricCongestion = TrafficDemoScenario(
    id: 'hcm_tran_quoc_thao_historic_congestion',
    title: 'Cao điểm · 07:00',
    subtitle: 'Demo cùng quãng đường',
    pickupAddress: 'Điểm lấy mẫu · trung tâm TP.HCM',
    pickup: LatLng(10.784900, 106.668400),
    deliveryAddress: 'Điểm giao mẫu · TP.HCM',
    delivery: LatLng(10.793838, 106.651842),
    isCongested: true,
  );

  static const hcmHistoricClearTraffic = TrafficDemoScenario(
    id: 'hcm_central_historic_clear_traffic',
    title: 'Ngoài cao điểm · 14:00',
    subtitle: 'Demo cùng quãng đường',
    pickupAddress: 'Điểm lấy mẫu · trung tâm TP.HCM',
    pickup: LatLng(10.784900, 106.668400),
    deliveryAddress: 'Điểm giao mẫu · TP.HCM',
    delivery: LatLng(10.793838, 106.651842),
    isCongested: false,
  );
}
