enum LocationIngestCoordinateSpace { rawGps, mapCoordinates }

extension LocationIngestCoordinateSpaceRules on LocationIngestCoordinateSpace {
  bool get shouldApplyDemoOffset =>
      this == LocationIngestCoordinateSpace.rawGps;
}

class DriverLocationProducerPolicy {
  const DriverLocationProducerPolicy._();

  static bool canPublishBackgroundGps(String? activeNavigationOrderId) {
    return activeNavigationOrderId == null ||
        activeNavigationOrderId.trim().isEmpty;
  }
}
