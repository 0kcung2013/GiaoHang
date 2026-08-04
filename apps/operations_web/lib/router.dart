import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/admin/screens/admin_shell_screen.dart';
import 'features/auth/operations_login_screen.dart';
import 'features/auth/unauthorized_screen.dart';
import 'features/risk_reports/screens/support_risk_reports_screen.dart';
import 'features/support/screens/support_home_screen.dart';

class _OperationsAuthNotifier extends ChangeNotifier {
  _OperationsAuthNotifier() {
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

Future<String?> _currentRole() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return null;
  final row = await client
      .from('users')
      .select('role')
      .eq('id', user.id)
      .single();
  return row['role']?.toString();
}

GoRouter createOperationsRouter() {
  final authNotifier = _OperationsAuthNotifier();
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (_, state) async {
      final user = Supabase.instance.client.auth.currentUser;
      final location = state.matchedLocation;
      if (user == null) return location == '/login' ? null : '/login';

      final role = await _currentRole();
      if (role != 'admin' && role != 'support') {
        return location == '/unauthorized' ? null : '/unauthorized';
      }
      if (location == '/' || location == '/login') {
        return role == 'admin' ? '/admin-home' : '/support-home';
      }
      if (location.startsWith('/admin') && role != 'admin') {
        return '/support-home';
      }
      if (location.startsWith('/support') &&
          role != 'support' &&
          role != 'admin') {
        return '/unauthorized';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(path: '/login', builder: (_, _) => const OperationsLoginScreen()),
      GoRoute(
        path: '/unauthorized',
        builder: (_, _) => const UnauthorizedScreen(),
      ),
      GoRoute(path: '/admin-home', builder: (_, _) => const AdminShellScreen()),
      GoRoute(
        path: '/support-home',
        builder: (_, _) => const SupportHomeScreen(),
      ),
      GoRoute(
        path: '/support-risk',
        builder: (_, _) => const SupportRiskReportsScreen(),
      ),
    ],
  );
}
