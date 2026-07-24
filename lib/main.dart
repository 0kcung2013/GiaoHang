import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_theme.dart';
import 'core/constants/supabase_constants.dart';
import 'core/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;
  final user = Supabase.instance.client.auth.currentUser;

  String initialLocation;
  if (user != null) {
    initialLocation = '/';
  } else if (onboardingDone) {
    initialLocation = '/login';
  } else {
    initialLocation = '/onboarding';
  }

  // DevicePreview trên điện thoại thật làm lệch/chặn touch → form login không bấm được.
  // Chỉ bật khi debug trên web / desktop.
  final useDevicePreview = !kReleaseMode &&
      (kIsWeb ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  runApp(
    ProviderScope(
      child: useDevicePreview
          ? DevicePreview(
              enabled: true,
              builder: (context) =>
                  CustomerApp(initialLocation: initialLocation),
            )
          : CustomerApp(initialLocation: initialLocation),
    ),
  );
}

class CustomerApp extends StatelessWidget {
  final String initialLocation;

  const CustomerApp({super.key, required this.initialLocation});

  @override
  Widget build(BuildContext context) {
    final useDevicePreview = !kReleaseMode &&
        (kIsWeb ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'DATN - Khách hàng',
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
