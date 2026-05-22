import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/supabase_constants.dart';
import 'core/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  runApp(CustomerApp(initialLocation: initialLocation));
}

class CustomerApp extends StatelessWidget {
  final String initialLocation;

  const CustomerApp({super.key, required this.initialLocation});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'DATN - Khách hàng',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: createRouter(initialLocation: initialLocation),
    );
  }
}
