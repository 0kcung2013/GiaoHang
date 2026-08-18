import '../../driver/screens/navigation/models/driver_position_source.dart';

enum ReturnConfirmationPositionStrategy {
  displayedPosition,
  serverProfile,
  liveGps,
}

abstract final class ReturnConfirmationPositionPolicy {
  static ReturnConfirmationPositionStrategy resolve({
    required bool isWeb,
    required DriverPositionSource displayedSource,
  }) {
    if (displayedSource == DriverPositionSource.simulation) {
      return ReturnConfirmationPositionStrategy.displayedPosition;
    }
    if (isWeb &&
        (displayedSource == DriverPositionSource.serverProfile ||
            displayedSource == DriverPositionSource.restoredSession ||
            displayedSource == DriverPositionSource.targetFallback)) {
      return ReturnConfirmationPositionStrategy.serverProfile;
    }
    return ReturnConfirmationPositionStrategy.liveGps;
  }
}
