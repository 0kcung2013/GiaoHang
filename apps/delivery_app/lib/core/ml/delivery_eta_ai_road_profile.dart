import 'dart:convert';
import 'dart:typed_data';

import 'delivery_eta_ai_road_profile_data.dart';

class DeliveryEtaRoadFeatures {
  const DeliveryEtaRoadFeatures({
    required this.lengthMeters,
    required this.speedLimitKmh,
    required this.level,
    required this.historicalSpeedRatio,
  });

  final double lengthMeters;
  final double speedLimitKmh;
  final double level;
  final double historicalSpeedRatio;
}

/// Compact, local lookup of the UTraffic road closest to an OSRM route point.
///
/// The profile is historical only. It never receives the driver's current
/// velocity, so it remains safe to use when the app is offline.
class DeliveryEtaAiRoadProfile {
  DeliveryEtaAiRoadProfile._();

  static const int _headerSize = 6;
  static const int _entrySize = 24;
  static const int _gridScale = 200;
  static final List<_RoadProfileEntry> _entries = _decodeEntries();
  static final Map<int, List<_RoadProfileEntry>> _grid = _buildGrid();

  static DeliveryEtaRoadFeatures? featuresNear({
    required double latitude,
    required double longitude,
  }) {
    if (!latitude.isFinite || !longitude.isFinite || _entries.isEmpty) {
      return null;
    }

    final cellLatitude = (latitude * _gridScale).floor();
    final cellLongitude = (longitude * _gridScale).floor();
    final candidates = <_RoadProfileEntry>[];
    for (var latitudeOffset = -1; latitudeOffset <= 1; latitudeOffset++) {
      for (var longitudeOffset = -1; longitudeOffset <= 1; longitudeOffset++) {
        candidates.addAll(
          _grid[_gridKey(
                cellLatitude + latitudeOffset,
                cellLongitude + longitudeOffset,
              )] ??
              const [],
        );
      }
    }
    return _nearestOf(
      candidates.isEmpty ? _entries : candidates,
      latitude,
      longitude,
    )?.features;
  }

  static _RoadProfileEntry? _nearestOf(
    List<_RoadProfileEntry> entries,
    double latitude,
    double longitude,
  ) {
    _RoadProfileEntry? nearest;
    var nearestDistanceSquared = double.infinity;
    for (final entry in entries) {
      final latitudeDelta = entry.latitude - latitude;
      // Longitude distance is slightly smaller at TP.HCM's latitude.
      final longitudeDelta = (entry.longitude - longitude) * 0.98;
      final distanceSquared =
          latitudeDelta * latitudeDelta + longitudeDelta * longitudeDelta;
      if (distanceSquared < nearestDistanceSquared) {
        nearest = entry;
        nearestDistanceSquared = distanceSquared;
      }
    }
    return nearest;
  }

  static Map<int, List<_RoadProfileEntry>> _buildGrid() {
    final grid = <int, List<_RoadProfileEntry>>{};
    for (final entry in _entries) {
      final key = _gridKey(
        (entry.latitude * _gridScale).floor(),
        (entry.longitude * _gridScale).floor(),
      );
      (grid[key] ??= <_RoadProfileEntry>[]).add(entry);
    }
    return Map.unmodifiable(grid);
  }

  static int _gridKey(int latitude, int longitude) =>
      latitude * 100000 + longitude;

  static List<_RoadProfileEntry> _decodeEntries() {
    final bytes = base64Decode(deliveryEtaAiRoadProfilePayload);
    final data = ByteData.sublistView(bytes);
    if (bytes.length < _headerSize ||
        bytes[0] != 0x52 ||
        bytes[1] != 0x50 ||
        bytes[2] != 0x46 ||
        bytes[3] != 0x31) {
      throw const FormatException('Invalid delivery ETA road profile payload.');
    }
    final count = data.getUint16(4, Endian.little);
    if (count != deliveryEtaAiRoadProfileCount ||
        bytes.length != _headerSize + count * _entrySize) {
      throw const FormatException('Unexpected delivery ETA road profile size.');
    }

    final entries = <_RoadProfileEntry>[];
    var offset = _headerSize;
    for (var index = 0; index < count; index++) {
      entries.add(
        _RoadProfileEntry(
          latitude: data.getFloat32(offset, Endian.little),
          longitude: data.getFloat32(offset + 4, Endian.little),
          features: DeliveryEtaRoadFeatures(
            lengthMeters: data.getFloat32(offset + 8, Endian.little),
            speedLimitKmh: data.getFloat32(offset + 12, Endian.little),
            level: data.getFloat32(offset + 16, Endian.little),
            historicalSpeedRatio: data.getFloat32(offset + 20, Endian.little),
          ),
        ),
      );
      offset += _entrySize;
    }
    return List.unmodifiable(entries);
  }
}

class _RoadProfileEntry {
  const _RoadProfileEntry({
    required this.latitude,
    required this.longitude,
    required this.features,
  });

  final double latitude;
  final double longitude;
  final DeliveryEtaRoadFeatures features;
}
