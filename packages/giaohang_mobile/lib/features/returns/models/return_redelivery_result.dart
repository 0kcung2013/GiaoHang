import 'package:latlong2/latlong.dart';

import '../../../core/models/order_model.dart';

class ReturnRedeliveryResult {
  const ReturnRedeliveryResult({required this.order, required this.position});

  final OrderModel order;
  final LatLng? position;
}
