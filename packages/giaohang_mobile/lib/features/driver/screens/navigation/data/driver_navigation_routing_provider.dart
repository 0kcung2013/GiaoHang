import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../../../../core/services/osrm_service.dart';

final driverNavigationTilesProvider = Provider<TileProvider?>((ref) => null);

final driverNavigationRoutingProvider = Provider<OsrmService>(
  (ref) => OsrmService(),
);
