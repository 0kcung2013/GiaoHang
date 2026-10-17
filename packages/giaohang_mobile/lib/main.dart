import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_config/giaohang_config.dart';
import 'core/location/driver_foreground_location_service.dart';
import 'core/location/driver_location_mode_store.dart';
import 'core/providers/location_providers.dart';
import 'core/router.dart';
import 'core/mobile_app_role.dart';

Future<void> runMobileApp(MobileAppRole role) async {
  WidgetsFlutterBinding.ensureInitialized();
  // `flutter_foreground_task` dùng dart:isolate nên không chạy được trên Web.
  // Chỉ Android/iOS mới cần foreground location service.
  if (!kIsWeb && role == MobileAppRole.driver) {
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
    authOptions: FlutterAuthClientOptions(
      localStorage: SharedPreferencesLocalStorage(
        persistSessionKey: role.sessionKey,
      ),
    ),
  );

  final user = Supabase.instance.client.auth.currentUser;
  final initialLocation = user == null ? '/login' : '/';
  final driverLocationMode = await DriverLocationModeStore().load();

  runApp(
    ProviderScope(
      overrides: [
        driverLocationModeProvider.overrideWith((ref) => driverLocationMode),
      ],
      child: DeliveryApp(initialLocation: initialLocation, role: role),
    ),
  );
}

typedef DeliveryRouterFactory =
    GoRouter Function({required String initialLocation});

class DeliveryApp extends StatefulWidget {
  final String initialLocation;
  final DeliveryRouterFactory? routerFactory;
  final MobileAppRole role;

  const DeliveryApp({
    super.key,
    required this.initialLocation,
    this.routerFactory,
    this.role = MobileAppRole.customer,
  });

  @override
  State<DeliveryApp> createState() => _DeliveryAppState();
}

class _DeliveryAppState extends State<DeliveryApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router =
        widget.routerFactory?.call(initialLocation: widget.initialLocation) ??
        createRouter(
          initialLocation: widget.initialLocation,
          role: widget.role,
        );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: widget.role.appName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bgLight,
      ),
      routerConfig: _router,
    );
  }
}
