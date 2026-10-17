import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'driver_delivery_arrival_strings.dart';

String deliveryArrivalErrorMessage(Object error) {
  if (error is PermissionDeniedException) {
    return DriverDeliveryArrivalStrings.locationPermission;
  }
  if (error is LocationServiceDisabledException) {
    return DriverDeliveryArrivalStrings.locationDisabled;
  }
  if (error is TimeoutException) {
    return DriverDeliveryArrivalStrings.locationTimeout;
  }
  if (error is PostgrestException) {
    return switch (error.message) {
      'DELIVERY_LOCATION_STALE' => DriverDeliveryArrivalStrings.locationStale,
      'DELIVERY_OUTSIDE_GEOFENCE' =>
        DriverDeliveryArrivalStrings.outsideGeofence,
      'DELIVERY_ARRIVAL_INVALID_STATUS' =>
        DriverDeliveryArrivalStrings.invalidStatus,
      _ => DriverDeliveryArrivalStrings.arrivalFailed,
    };
  }
  return DriverDeliveryArrivalStrings.arrivalFailed;
}
