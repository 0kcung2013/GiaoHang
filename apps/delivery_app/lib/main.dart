import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_config/giaohang_config.dart';
import 'core/location/driver_foreground_location_service.dart';
import 'core/location/driver_location_mode_store.dart';
import 'core/providers/location_providers.dart';
import 'core/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // `flutter_foreground_task` dùng dart:isolate nên không chạy được trên Web.
  // Chỉ Android/iOS mới cần foreground location service.
  if (!kIsWeb) {
    FlutterForegroundTask.initCommunicationPort();
    DriverForegroundLocationService.initialize();
  }

  if (kIsWeb) {
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('window.dart')) return;
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (exception, stack) {
      if (exception.toString().contains('window.dart')) return true;
      return false;
    };
  }

  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );

  final user = Supabase.instance.client.auth.currentUser;
  final initialLocation = user == null ? '/login' : '/';
  final driverLocationMode = await DriverLocationModeStore().load();

  // DevicePreview trên điện thoại thật làm lệch/chặn touch → form login không bấm được.
  // Chỉ bật khi debug trên web / desktop.
  final useDevicePreview =
      !kReleaseMode &&
      (kIsWeb ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  runApp(
    ProviderScope(
      overrides: [
        driverLocationModeProvider.overrideWith((ref) => driverLocationMode),
      ],
      child: useDevicePreview
          ? DevicePreview(
              enabled: true,
              builder: (context) =>
                  DeliveryApp(initialLocation: initialLocation),
            )
          : DeliveryApp(initialLocation: initialLocation),
    ),
  );
}

class DeliveryApp extends StatelessWidget {
  final String initialLocation;

  const DeliveryApp({super.key, required this.initialLocation});

  @override
  Widget build(BuildContext context) {
    final useDevicePreview =
        !kReleaseMode &&
        (kIsWeb ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Giao Hàng - Customer & Driver',
      locale: useDevicePreview ? DevicePreview.locale(context) : null,
      builder: useDevicePreview ? DevicePreview.appBuilder : null,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bgLight,
      ),
      routerConfig: createRouter(initialLocation: initialLocation),
    );
  }
}
