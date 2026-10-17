import 'package:shared_preferences/shared_preferences.dart';

import 'driver_location_producer_policy.dart';

class DriverLocationModeStore {
  DriverLocationModeStore({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  static const _preferenceKey = 'driver.location_mode.v1';

  final Future<SharedPreferences> Function() _preferences;

  Future<DriverLocationMode> load() async {
    final preferences = await _preferences();
    final storedName = preferences.getString(_preferenceKey);

    return DriverLocationMode.values.firstWhere(
      (mode) => mode.name == storedName,
      orElse: () => DriverLocationMode.deviceGps,
    );
  }

  Future<void> save(DriverLocationMode mode) async {
    final preferences = await _preferences();
    await preferences.setString(_preferenceKey, mode.name);
  }
}
