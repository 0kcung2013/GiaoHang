import '../../driver/screens/navigation/models/driver_position_source.dart';

enum ReturnConfirmationPositionStrategy {
  displayedPosition,
  serverProfile,
  liveGps,
}

abstract final class ReturnConfirmationPositionPolicy {
  static ReturnConfirmationPositionStrategy resolve({
    required bool usesRouteSimulation,
    required DriverPositionSource displayedSource,
  }) {
    if (displayedSource == DriverPositionSource.simulation ||
        (usesRouteSimulation &&
            displayedSource == DriverPositionSource.restoredSession)) {
      return ReturnConfirmationPositionStrategy.displayedPosition;
    }
    if (usesRouteSimulation &&
        (displayedSource == DriverPositionSource.serverProfile ||
            displayedSource == DriverPositionSource.targetFallback)) {
      return ReturnConfirmationPositionStrategy.serverProfile;
    }
    return ReturnConfirmationPositionStrategy.liveGps;
  }
}
