import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'driver_presence_strings.dart';

enum LocationFailure {
  permissionDenied,
  serviceDisabled,
  timeout,
  unavailable;

  static LocationFailure from(Object error) => switch (error) {
    PermissionDeniedException() => permissionDenied,
    LocationServiceDisabledException() => serviceDisabled,
    TimeoutException() => timeout,
    _ => unavailable,
  };

  String get message => switch (this) {
    permissionDenied => DriverPresenceStrings.permissionDenied,
    serviceDisabled => DriverPresenceStrings.serviceDisabled,
    timeout => DriverPresenceStrings.gpsTimedOut,
    unavailable => DriverPresenceStrings.positionUnavailable,
  };
}
