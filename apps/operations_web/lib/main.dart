import 'package:flutter/material.dart';
import 'package:giaohang_config/giaohang_config.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );
  runApp(const OperationsApp());
}

typedef OperationsRouterFactory = GoRouter Function();

class OperationsApp extends StatefulWidget {
  final OperationsRouterFactory routerFactory;

  const OperationsApp({super.key, this.routerFactory = createOperationsRouter});

  @override
  State<OperationsApp> createState() => _OperationsAppState();
}

class _OperationsAppState extends State<OperationsApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = widget.routerFactory();
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
      title: 'Giao Hàng — Vận hành',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.bgCard,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bgLight,
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: AppColors.primary,
          selectionColor: AppColors.accentLight,
        ),
      ),
      routerConfig: _router,
    );
  }
}
