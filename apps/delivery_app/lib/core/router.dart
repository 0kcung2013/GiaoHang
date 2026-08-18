import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/screens/driver_approval/driver_approval_screen.dart';
import '../features/auth/screens/driver_auth/driver_auth_screen.dart';
import '../features/auth/screens/login/login_screen.dart';
import '../features/auth/screens/register/register_screen.dart';
import '../features/customer/screens/create_order/create_order_screen.dart';
import '../features/customer/screens/create_order/order_confirmation_screen.dart';
import '../features/customer/screens/create_order/order_success_screen.dart';
import '../features/customer/screens/home/home_screen.dart';
import '../features/driver/screens/driver_shell_screen.dart';
import '../features/auth/screens/operations_required_screen.dart';
import '../features/auth/screens/unsupported_role_screen.dart';

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

Future<String?> _fetchDriverApproval(
  SupabaseClient supabase,
  String userId,
) async {
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
          location == '/driver-auth' ||
          location == '/register' ||
          location == '/driver-pending';

      final uri = state.uri.toString();

      if (uri.contains('code=') || uri.contains('access_token=')) return null;

      if (loggedIn) {
        if (location == '/' || location == '/login') {
          final result = await supabase
              .from('users')
              .select('role')
              .eq('id', user.id)
              .single();
          final role = result['role'] as String?;
          switch (role) {
            case 'admin':
              return '/operations-required';
            case 'driver':
              final approval = await _fetchDriverApproval(supabase, user.id);
              if (approval != 'approved') return '/driver-pending';
              return '/driver-home';
            case 'support':
              return '/operations-required';
            case 'customer':
              return '/customer-home';
            default:
              return '/unsupported-role';
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

        if (location == '/customer-home' || location.startsWith('/customer/')) {
          final roleResult = await supabase
              .from('users')
              .select('role')
              .eq('id', user.id)
              .single();
          if (roleResult['role'] != 'customer') return '/unsupported-role';
        }

        return null;
      }

      if (location == '/' || !publicRoute) return '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/driver-auth',
        builder: (_, state) => DriverAuthScreen(extra: state.extra),
      ),
      GoRoute(
        path: '/driver-pending',
        builder: (_, _) => const DriverApprovalScreen(),
      ),
      GoRoute(
        path: '/customer-home',
        builder: (_, state) {
          final tab = state.uri.queryParameters['tab'];
          final code = state.uri.queryParameters['code'];
          final initialTab = switch (tab) {
            'orders' => 1,
            'tracking' => 2,
            'account' => 3,
            _ => 0,
          };
          return CustomerHomeScreen(
            initialTab: initialTab,
            initialTrackingCode: code,
          );
        },
      ),
      GoRoute(
        path: '/customer/create-order',
        builder: (_, _) => const CreateOrderScreen(),
        routes: [
          GoRoute(
            path: 'confirm',
            builder: (_, state) {
              final formData = state.extra as dynamic;
              return OrderConfirmationScreen(formData: formData as dynamic);
            },
          ),
          GoRoute(
            path: 'success',
            builder: (_, state) {
              final extra = state.extra;
              final map = extra is Map
                  ? Map<String, dynamic>.from(extra)
                  : <String, dynamic>{};
              return OrderSuccessScreen(
                orderId: map['orderId']?.toString() ?? '',
                trackingCode: map['trackingCode']?.toString() ?? '',
                deliveryFee: (map['deliveryFee'] as num?)?.toDouble() ?? 0,
                distanceKm: (map['distanceKm'] as num?)?.toDouble(),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/driver-home',
        builder: (_, state) {
          final tab = state.uri.queryParameters['tab'];
          final initialTab = switch (tab) {
            'orders' => 1,
            'earnings' => 2,
            'account' => 3,
            _ => 0,
          };
          return DriverShellScreen(initialTab: initialTab);
        },
      ),
      GoRoute(
        path: '/operations-required',
        builder: (_, _) => const OperationsRequiredScreen(),
      ),
      GoRoute(
        path: '/unsupported-role',
        builder: (_, _) => const UnsupportedRoleScreen(),
      ),
    ],
  );
}
