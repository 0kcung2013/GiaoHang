import 'dart:async';
import 'mobile_app_role.dart';
import 'mobile_route_policy.dart';

import 'package:flutter/widgets.dart';
import 'package:giaohang_config/giaohang_config.dart';
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
  late final SupabaseSingleSessionController _singleSessionController;

  void start(MobileAppRole role) {
    final client = Supabase.instance.client;
    _singleSessionController = SupabaseSingleSessionController(client: client);
    _subscription = client.auth.onAuthStateChange.listen((state) {
      unawaited(_handleAuthState(state, role));
      notifyListeners();
    });
  }

  Future<void> _handleAuthState(AuthState state, MobileAppRole role) async {
    try {
      final user = state.session?.user;
      if (user != null) {
        final record = await Supabase.instance.client
            .from('users')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();
        // Logging into the wrong app must not revoke the correct app session.
        if (!role.accepts(record?['role'] as String?)) return;
      }
      await _singleSessionController.handleAuthState(state);
    } catch (_) {
      // Router/backend still enforce access if session synchronization fails.
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    unawaited(_singleSessionController.dispose());
    super.dispose();
  }
}

Future<String?> _fetchDriverApproval(SupabaseClient supabase) async {
  try {
    final result = await supabase.rpc('get_my_driver_account_profile');
    if (result is! Map) return null;
    return result['approval_status']?.toString();
  } catch (_) {
    return null;
  }
}

GoRouter createRouter({
  required String initialLocation,
  MobileAppRole role = MobileAppRole.customer,
}) {
  final authNotifier = _AuthStateNotifier();
  authNotifier.start(role);

  return _MobileRouter(
    initialLocation: initialLocation,
    refreshListenable: authNotifier,
    redirect: (context, state) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      final loggedIn = user != null;
      final location = state.matchedLocation;
      String? accountRole;
      String? approval;
      if (user != null) {
        final result = await supabase
            .from('users')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();
        accountRole = result?['role'] as String?;
        if (role == MobileAppRole.driver &&
            role.accepts(accountRole) &&
            location != '/register') {
          approval = await _fetchDriverApproval(supabase);
        }
      }
      return mobileRouteRedirect(
        app: role,
        location: location,
        signedIn: loggedIn,
        accountRole: accountRole,
        driverApproval: approval,
      );
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(
        path: '/login',
        builder: (_, _) => role == MobileAppRole.customer
            ? const LoginScreen()
            : const DriverAuthScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, _) => role == MobileAppRole.customer
            ? const RegisterScreen()
            : const DriverAuthScreen(register: true),
      ),
      if (role == MobileAppRole.driver)
        GoRoute(
          path: '/driver-pending',
          builder: (_, _) => const DriverApprovalScreen(),
        ),
      if (role == MobileAppRole.customer)
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
      if (role == MobileAppRole.customer)
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
      if (role == MobileAppRole.driver)
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
        builder: (_, _) => UnsupportedRoleScreen(expectedRole: role),
      ),
    ],
  );
}

class _MobileRouter extends GoRouter {
  _MobileRouter({
    required super.initialLocation,
    required _AuthStateNotifier refreshListenable,
    required GoRouterRedirect redirect,
    required List<RouteBase> routes,
  }) : _authNotifier = refreshListenable,
       super.routingConfig(
         refreshListenable: refreshListenable,
         routingConfig: ValueNotifier(
           RoutingConfig(routes: routes, redirect: redirect),
         ),
       );
  final _AuthStateNotifier _authNotifier;
  @override
  void dispose() {
    super.dispose();
    _authNotifier.dispose();
  }
}
