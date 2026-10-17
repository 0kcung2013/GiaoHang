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

  /// Comparison hours; operational assignment clocks remain real.
  String get key =>
      isCongested ? TrafficDemoClock.peak : TrafficDemoClock.offPeak;
  DateTime get forecastAt => TrafficDemoClock.forecastAt(key)!;

  static const hcmHistoricCongestion = TrafficDemoScenario(
    id: 'hcm_tran_quoc_thao_historic_congestion',
    title: 'Cao điểm · 18:00',
    subtitle: 'Demo cùng quãng đường',
    pickupAddress: 'Cửa hàng Thiên Anh · 19A Linh Đông',
    pickup: LatLng(10.8456193, 106.7459414),
    deliveryAddress: 'Co.op Food · 103 Linh Đông',
    delivery: LatLng(10.850616, 106.747684),
    isCongested: true,
  );

  static const hcmHistoricClearTraffic = TrafficDemoScenario(
    id: 'hcm_central_historic_clear_traffic',
    title: 'Ngoài cao điểm · 12:00',
    subtitle: 'Demo cùng quãng đường',
    pickupAddress: 'Cửa hàng Thiên Anh · 19A Linh Đông',
    pickup: LatLng(10.8456193, 106.7459414),
    deliveryAddress: 'Co.op Food · 103 Linh Đông',
    delivery: LatLng(10.850616, 106.747684),
    isCongested: false,
  );
}
