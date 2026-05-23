import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/admin/screens/home/home_screen.dart';
import '../features/auth/screens/login/login_screen.dart';
import '../features/customer/screens/home/home_screen.dart';
import '../features/driver/screens/home/home_screen.dart';
import '../features/onboarding/screens/onboarding/onboarding_screen.dart';

class _AuthStateNotifier extends ChangeNotifier {
  StreamSubscription? _subscription;

  void start() {
    _subscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

GoRouter createRouter({required String initialLocation}) {
  final authNotifier = _AuthStateNotifier();
  authNotifier.start();

  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: authNotifier,
    redirect: (context, state) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      final loggedIn = user != null;
      final uri = state.uri.toString();
      final location = state.matchedLocation;

      // OAuth callback — để Supabase xử lý token trước
      if (uri.contains('code=') || uri.contains('access_token=')) return null;

      if (loggedIn) {
        if (location == '/' || location == '/login' || location == '/onboarding') {
          final result = await supabase
              .from('users')
              .select('role')
              .eq('id', user.id)
              .single();
          final role = result['role'] as String?;
          switch (role) {
            case 'admin':
              return '/admin-home';
            case 'driver':
              return '/driver-home';
            default:
              return '/customer-home';
          }
        }
        return null;
      }

      if (location == '/') return '/login';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: '/customer-home',
        builder: (_, _) => const CustomerHomeScreen(),
      ),
      GoRoute(
        path: '/driver-home',
        builder: (_, _) => const DriverHomeScreen(),
      ),
      GoRoute(
        path: '/admin-home',
        builder: (_, _) => const AdminHomeScreen(),
      ),
    ],
  );
}
