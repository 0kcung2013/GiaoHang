import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/admin/screens/admin_shell_screen.dart';
import '../features/auth/screens/driver_approval/driver_approval_screen.dart';
import '../features/auth/screens/driver_auth/driver_auth_screen.dart';
import '../features/auth/screens/login/login_screen.dart';
import '../features/auth/screens/register/register_screen.dart';
import '../features/customer/screens/create_order/create_order_screen.dart';
import '../features/customer/screens/home/home_screen.dart';
import '../features/driver/screens/driver_shell_screen.dart';
import '../features/onboarding/screens/onboarding/onboarding_screen.dart';

class _AuthStateNotifier extends ChangeNotifier {
  StreamSubscription? _subscription;

  void start() {
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

Future<String?> _fetchDriverApproval(SupabaseClient supabase, String userId) async {
  try {
    final result = await supabase
        .from('drivers')
        .select('approval_status')
        .eq('user_id', userId)
        .single();
    return result['approval_status'] as String?;
  } catch (_) {
    return null;
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
      final location = state.matchedLocation;
      final publicRoute =
          location == '/login' ||
          location == '/onboarding' ||
          location == '/driver-auth' ||
          location == '/register' ||
          location == '/driver-pending';

      final uri = state.uri.toString();

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
              final approval = await _fetchDriverApproval(supabase, user.id);
              if (approval != 'approved') return '/driver-pending';
              return '/driver-home';
            default:
              return '/customer-home';
          }
        }

        if (location == '/driver-home' || location.startsWith('/driver-')) {
          final roleResult = await supabase
              .from('users')
              .select('role')
              .eq('id', user.id)
              .single();
          if ((roleResult['role'] as String?) != 'driver') {
            return '/login';
          }

          if (location != '/driver-pending') {
            final approval = await _fetchDriverApproval(supabase, user.id);
            if (approval != 'approved') return '/driver-pending';
          }
        }

        return null;
      }

      if (location == '/' || !publicRoute) return '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/driver-auth',
        builder: (_, _) => const DriverAuthScreen(),
      ),
      GoRoute(
        path: '/driver-pending',
        builder: (_, _) => const DriverApprovalScreen(),
      ),
      GoRoute(
        path: '/customer-home',
        builder: (_, _) => const CustomerHomeScreen(),
      ),
      GoRoute(
        path: '/customer/create-order',
        builder: (_, _) => const CreateOrderScreen(),
      ),
      GoRoute(
        path: '/driver-home',
        builder: (_, _) => const DriverShellScreen(),
      ),
      GoRoute(path: '/admin-home', builder: (_, _) => const AdminShellScreen()),
    ],
  );
}
