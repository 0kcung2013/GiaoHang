import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:giaohang_config/giaohang_config.dart';
import 'location_ingest_service.dart';

/// Quyền vị trí đạt được khi tài xế bắt đầu giao hàng.
///
/// Android 11+ có thể chỉ trả về [whileInUse] ở hộp thoại đầu tiên. Foreground
/// service vẫn tiếp tục được phép theo dõi cho phiên giao đang chạy; quyền
/// [always] giúp hệ điều hành cho phép khởi động lại tác vụ vị trí từ nền.
enum DriverLocationPermission { denied, whileInUse, always }

/// Foreground service Android cho phiên giao hàng đang active.
///
/// Service độc lập với màn Map: isolate nền tự lấy GPS và gọi pipeline ingest
/// hiện có. Vì thế khách vẫn nhận vị trí mới khi tài xế thu nhỏ app hoặc trở về
/// dashboard. Service chỉ khởi động từ thao tác mở điều hướng và phải dừng khi
/// đơn hoàn tất/hủy.
class DriverForegroundLocationService {
  DriverForegroundLocationService._();

  static const _serviceId = 601;
  static const _driverProfileIdKey = 'delivery_driver_profile_id';
  static const _driverUserIdKey = 'delivery_driver_user_id';
  static bool _initialized = false;

  static void initialize() {
    if (kIsWeb || _initialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'driver_location_tracking',
        channelName: 'Theo dõi vị trí giao hàng',
        channelDescription:
            'Đang chia sẻ vị trí tài xế cho đơn hàng đang giao.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        allowWakeLock: true,
        allowWifiLock: false,
        allowAutoRestart: true,
        stopWithTask: false,
      ),
    );
    _initialized = true;
  }

  static Future<DriverLocationPermission> requestLocationPermission() async {
    if (kIsWeb || !Platform.isAndroid) {
      return DriverLocationPermission.always;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return switch (permission) {
      LocationPermission.always => DriverLocationPermission.always,
      LocationPermission.whileInUse => DriverLocationPermission.whileInUse,
      _ => DriverLocationPermission.denied,
    };
  }

  static Future<bool> start({
    required String driverProfileId,
    required String driverUserId,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    initialize();

    final locationPermission = await requestLocationPermission();
    if (locationPermission == DriverLocationPermission.denied) return false;

    final notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    await FlutterForegroundTask.saveData(
      key: _driverProfileIdKey,
      value: driverProfileId,
    );
    await FlutterForegroundTask.saveData(
      key: _driverUserIdKey,
      value: driverUserId,
    );

    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask({
        'driverProfileId': driverProfileId,
        'driverUserId': driverUserId,
      });
      return true;
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: 'Đang chia sẻ vị trí',
      notificationText: 'Vị trí được cập nhật khi đang giao hàng',
      callback: startDriverForegroundLocationTask,
    );
    return result is ServiceRequestSuccess;
  }

  static Future<void> stop() async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
    await FlutterForegroundTask.removeData(key: _driverProfileIdKey);
    await FlutterForegroundTask.removeData(key: _driverUserIdKey);
  }
}

/// Entry point bắt buộc là top-level để Android mở isolate foreground service.
@pragma('vm:entry-point')
void startDriverForegroundLocationTask() {
  FlutterForegroundTask.setTaskHandler(_DriverForegroundLocationTaskHandler());
}

class _DriverForegroundLocationTaskHandler extends TaskHandler {
  StreamSubscription<Position>? _positionStream;
  LocationIngestService? _ingest;
  String? _driverProfileId;
  String? _driverUserId;
  bool _uploading = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    await _restoreDeliveryContext();
    await _initializeUploader();
    _startGpsStream();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // GPS stream chủ động theo thay đổi vị trí; repeat giữ foreground isolate
    // hoạt động đều đặn để Android không thu hồi service giữa phiên giao.
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _positionStream?.cancel();
    _positionStream = null;
    await _ingest?.dispose();
    _ingest = null;
  }

  @override
  void onReceiveData(Object data) {
    if (data is! Map) return;
    final profileId = data['driverProfileId']?.toString();
    final userId = data['driverUserId']?.toString();
    if (profileId == null ||
        profileId.isEmpty ||
        userId == null ||
        userId.isEmpty) {
      return;
    }
    _driverProfileId = profileId;
    _driverUserId = userId;
  }

  Future<void> _restoreDeliveryContext() async {
    _driverProfileId = await FlutterForegroundTask.getData<String>(
      key: DriverForegroundLocationService._driverProfileIdKey,
    );
    _driverUserId = await FlutterForegroundTask.getData<String>(
      key: DriverForegroundLocationService._driverUserIdKey,
    );
  }

  Future<void> _initializeUploader() async {
    try {
      await Supabase.initialize(
        url: SupabaseConstants.supabaseUrl,
        anonKey: SupabaseConstants.supabaseAnonKey,
      );
      _ingest = LocationIngestService();
    } catch (error) {
      debugPrint('[ForegroundGPS] Cannot initialize uploader: $error');
    }
  }

  void _startGpsStream() {
    _positionStream?.cancel();
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen(
          _publish,
          onError: (Object error) {
            debugPrint('[ForegroundGPS] Stream error: $error');
          },
        );
  }

  void _publish(Position position) {
    if (_uploading ||
        _ingest == null ||
        _driverProfileId == null ||
        _driverUserId == null) {
      return;
    }
    _uploading = true;
    unawaited(() async {
      try {
        await _ingest!.ingest(
          driverProfileId: _driverProfileId,
          driverUserId: _driverUserId,
          lat: position.latitude,
          lng: position.longitude,
          heading: position.heading,
          speed: position.speed,
          prioritySync: true,
        );
        FlutterForegroundTask.sendDataToMain({
          'type': 'driver_location',
          'lat': position.latitude,
          'lng': position.longitude,
        });
      } finally {
        _uploading = false;
      }
    }());
  }
}
