import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:operations_web/core/widgets/admin_workspace_scope.dart';
import 'package:operations_web/features/admin/constants/admin_strings.dart';
import 'package:operations_web/features/admin/models/admin_section.dart';
import 'package:operations_web/features/admin/screens/admin_shell_screen.dart';
import 'package:operations_web/features/admin/screens/dashboard/admin_dashboard_screen.dart';
import 'package:operations_web/features/admin/screens/accounts/admin_accounts_screen.dart';
import 'package:operations_web/features/admin/models/admin_snapshot.dart';
import 'package:operations_web/features/admin/widgets/admin_decision_queue.dart';
import 'package:operations_web/features/admin/widgets/admin_metrics.dart';
import 'package:operations_web/features/support/widgets/support_workspace_scaffold.dart';
import 'helpers/admin_test_fixtures.dart';

void main() {
  setUpAll(loadAdminTestFonts);
  testWidgets(
    'admin prioritizes governance and keeps operational lookups collapsed until requested',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final built = <AdminSection>[];
      final router = GoRouter(
        initialLocation: '/admin-home',
        routes: [
          GoRoute(
            path: '/admin-home',
            builder: (_, state) => AdminShellScreen(
              section: AdminSection.parse(state.uri.queryParameters['section']),
              sectionBuilder: (section) {
                built.add(section);
                return _DraftPage(section: section);
              },
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(built.toSet(), {AdminSection.overview});
      for (final section in AdminSection.primary) {
        expect(
          find.byKey(ValueKey('admin-nav-${section.slug}')),
          findsOneWidget,
        );
      }
      for (final section in AdminSection.lookups) {
        expect(find.byKey(ValueKey('admin-nav-${section.slug}')), findsNothing);
      }
      await tester.enterText(find.byType(TextField), 'giữ bộ lọc');
      await tester.tap(find.byKey(const ValueKey('admin-lookup-toggle')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('admin-nav-orders')),
      );
      await tester.tap(find.byKey(const ValueKey('admin-nav-orders')));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.queryParameters['section'],
        'orders',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('admin-nav-overview')),
      );
      await tester.tap(find.byKey(const ValueKey('admin-nav-overview')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'giữ bộ lọc',
      );
      expect(built.toSet(), {AdminSection.overview, AdminSection.orders});
    },
  );

  testWidgets(
    'overview prioritizes Admin decisions and never loads the daily order feed',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeAdminRepository(), orders = FakeAdminOrders();
      await tester.pumpWidget(
        adminTestApp(
          AdminShellScreen(
            repository: repository,
            orderRepository: orders,
            onNavigate: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.snapshotReads, 1);
      expect(orders.reads, 0);
      expect(find.text(AdminStrings.recent), findsNothing);
      expect(
        tester.getTopLeft(find.byType(AdminDecisionQueue)).dy,
        lessThan(tester.getTopLeft(find.byType(AdminMetrics)).dy),
      );
    },
  );

  testWidgets(
    'direct links preserve account filters while obsolete escalation routes fall back to overview',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: '/admin-home?section=orders',
        routes: [
          GoRoute(
            path: '/admin-home',
            builder: (_, state) => AdminShellScreen(
              section: AdminSection.parse(state.uri.queryParameters['section']),
              view: state.uri.queryParameters['view'] ?? '',
              sectionBuilder: (_) => const SizedBox(),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('admin-nav-orders')), findsOneWidget);
      router.go('/admin-home?section=accounts&view=disabled');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('admin-nav-overview')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('admin-nav-accounts')));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.queryParameters['view'],
        'disabled',
      );
    },
  );

  testWidgets('Ctrl K opens searchable navigation with keyboard submit', (
    tester,
  ) async {
    AdminSection? selected;
    await tester.pumpWidget(
      adminTestApp(
        AdminShellScreen(
          onNavigate: (s) => selected = s,
          sectionBuilder: (_) => const SizedBox(),
        ),
      ),
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'GH-100');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(selected, AdminSection.orders);
  });

  for (final size in [
    const Size(320, 568),
    const Size(768, 1024),
    const Size(1366, 768),
  ]) {
    testWidgets('dashboard adapts at $size with 160 percent text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeAdminRepository(), orders = FakeAdminOrders();
      await tester.pumpWidget(
        adminTestApp(
          AdminShellScreen(
            repository: repo,
            orderRepository: orders,
            onNavigate: (_) {},
            sectionBuilder: (s) => AdminDashboardScreen(
              repository: repo,
              onNavigate: (_) {},
              onProfileChanges: () {},
            ),
          ),
          scale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(AdminStrings.overview), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (size.width < 1100) {
        await tester.tap(find.byTooltip(AdminStrings.menu));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('admin-nav-accounts')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('admin-nav-orders')), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets(
    'partial errors never show unknown values as zero and actions navigate',
    (tester) async {
      final repo = FakeAdminRepository();
      repo.snapshot = AdminSnapshot(
        values: {for (final m in AdminMetric.values) m: null},
        updatedAt: DateTime.utc(2026),
      );
      AdminSection? selected;
      var changes = 0;
      await tester.pumpWidget(
        adminTestApp(
          AdminDashboardScreen(
            repository: repo,
            onNavigate: (s) => selected = s,
            onProfileChanges: () => changes++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(AdminStrings.partialError), findsOneWidget);
      expect(find.text('0'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('admin-decision-disabledAccounts')),
      );
      await tester.tap(
        find.byKey(const ValueKey('admin-decision-disabledAccounts')),
      );
      expect(selected, AdminSection.accounts);
      await tester.ensureVisible(
        find.byKey(const ValueKey('admin-decision-changes')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('admin-decision-changes')));
      expect(changes, 1);
    },
  );

  testWidgets('embedded support tools keep one administrator frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      adminTestApp(
        const AdminWorkspaceScope(
          child: SupportWorkspaceScaffold(
            activeSection: SupportWorkspaceSection.tickets,
            body: Text('hồ sơ nghiệp vụ'),
          ),
        ),
      ),
    );
    expect(find.text('hồ sơ nghiệp vụ'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
  });

  testWidgets(
    'account list filters roles, retries failures, and opens details',
    (tester) async {
      final repo = FakeAdminRepository()..fail = true;
      await tester.pumpWidget(
        adminTestApp(AdminAccountsScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      expect(find.text(AdminStrings.loadError), findsOneWidget);
      repo.fail = false;
      await tester.tap(find.text(AdminStrings.retry));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Tài xế'));
      await tester.pumpAndSettle();
      expect(repo.role, 'driver');
      await tester.tap(find.text('Nguyễn Minh An'));
      await tester.pumpAndSettle();
      expect(find.text('0900000000'), findsOneWidget);
      expect(find.text('ID'), findsOneWidget);
    },
  );
}

class _DraftPage extends StatefulWidget {
  const _DraftPage({required this.section});
  final AdminSection section;
  @override
  State<_DraftPage> createState() => _DraftPageState();
}

class _DraftPageState extends State<_DraftPage> {
  final text = TextEditingController();
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(controller: text);
}
