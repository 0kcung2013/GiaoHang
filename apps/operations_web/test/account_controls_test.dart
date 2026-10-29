import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:operations_web/features/account_controls/constants/account_strings.dart';
import 'package:operations_web/features/account_controls/controllers/account_directory_controller.dart';
import 'package:operations_web/features/account_controls/dialogs/account_decision_dialog.dart';
import 'package:operations_web/features/account_controls/dialogs/account_history_dialog.dart';
import 'package:operations_web/features/account_controls/models/staff_account.dart';
import 'package:operations_web/features/account_controls/screens/account_controls_screen.dart';
import 'helpers/account_test_repository.dart';
import 'helpers/admin_test_fixtures.dart';

void main() {
  setUpAll(loadAdminTestFonts);
  testWidgets(
    'support filters the server directory, retries load failure and can disable accounts',
    (tester) async {
      final repo = FakeAccountRepository()..fail = true;
      await tester.pumpWidget(
        adminTestApp(AccountControlsScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      expect(find.text(AccountStrings.error), findsOneWidget);
      repo.fail = false;
      await tester.tap(find.text(AccountStrings.retry));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, 'CSKH'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Tài xế'));
      await tester.pumpAndSettle();
      expect(repo.role, 'driver');
      await tester.tap(
        find.widgetWithText(FilterChip, AccountStrings.disabledOnly),
      );
      await tester.pumpAndSettle();
      expect(repo.disabledOnly, isTrue);
      await tester.tap(find.text(accountFixture.name));
      await tester.pumpAndSettle();
      expect(find.text(AccountStrings.action('disable')), findsOneWidget);
      expect(find.text(AccountStrings.action('adjust')), findsNothing);
      expect(find.text(AccountStrings.action('release')), findsNothing);
    },
  );
  testWidgets(
    'support sees an existing decision while only Admin may adjust or release',
    (tester) async {
      for (final admin in [false, true]) {
        await tester.pumpWidget(
          adminTestApp(
            AccountHistoryDialog(
              account: disabledAccountFixture,
              repository: FakeAccountRepository(),
              isAdmin: admin,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(AccountStrings.action('disable')), findsNothing);
        expect(
          find.text(AccountStrings.action('adjust')),
          admin ? findsOneWidget : findsNothing,
        );
        expect(
          find.text(AccountStrings.action('release')),
          admin ? findsOneWidget : findsNothing,
        );
      }
    },
  );
  testWidgets(
    'ambiguous submit freezes its payload and retries the same decision exactly once',
    (tester) async {
      final repo = FakeAccountRepository();
      final pending = Completer<void>();
      repo.onApply = (_) => repo.commands.length == 1
          ? Future.error(TimeoutException('lost receipt'))
          : pending.future;
      await tester.pumpWidget(
        adminTestApp(
          AccountDecisionDialog(
            account: accountFixture,
            action: 'disable',
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, AccountStrings.action('disable')),
      );
      await tester.pumpAndSettle();
      expect(repo.commands, isEmpty);
      await tester.enterText(
        find.byType(TextFormField),
        'Vi phạm đã được kiểm chứng.',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, AccountStrings.action('disable')),
      );
      await tester.pumpAndSettle();
      expect(find.text(AccountStrings.uncertain), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      await tester.tap(find.text(AccountStrings.retryCommand));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(repo.commands.length, 2);
      expect(identical(repo.commands[0], repo.commands[1]), isTrue);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, AccountStrings.close),
            )
            .onPressed,
        isNull,
      );
      pending.complete();
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'permanent control, Admin release and concurrency conflicts use expected event',
    (tester) async {
      final repo = FakeAccountRepository();
      repo.onApply = (_) async {
        throw const PostgrestException(
          message: 'ACCOUNT_CONTROL_CHANGED',
          code: '40001',
        );
      };
      await tester.pumpWidget(
        adminTestApp(
          AccountDecisionDialog(
            account: disabledAccountFixture,
            action: 'adjust',
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-duration')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(AccountStrings.permanent).last);
      await tester.tap(find.text(AccountStrings.permanent).last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Đã kiểm chứng vi phạm nghiêm trọng.',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, AccountStrings.action('adjust')),
      );
      await tester.pumpAndSettle();
      expect(repo.commands.single.durationMinutes, isNull);
      expect(
        repo.commands.single.expectedEventId,
        disabledAccountFixture.eventId,
      );
      expect(find.text(AccountStrings.changed), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'filter changes discard in-flight old pages before debounce finishes',
    (tester) async {
      final first = Completer<AccountPage<StaffAccount>>();
      final repo = FakeAccountRepository()..onList = () => first.future;
      final controller = AccountDirectoryController(repo);
      addTearDown(controller.dispose);
      unawaited(controller.load());
      controller.filter(query: 'mới');
      first.complete(
        AccountPage(
          rows: [accountFixture],
          hasMore: true,
          serverNow: DateTime.now(),
        ),
      );
      await tester.pump();
      expect(controller.rows, isEmpty);
      repo.onList = null;
      repo.rows = [disabledAccountFixture];
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(controller.rows.single.disabled, isTrue);
      expect(repo.search, 'mới');
    },
  );
  for (final size in [const Size(320, 568), const Size(1440, 900)]) {
    testWidgets(
      'account directory and decision fit $size at 160 percent text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final repo = FakeAccountRepository();
        await tester.pumpWidget(
          adminTestApp(
            AccountControlsScreen(isAdmin: true, repository: repo),
            scale: 1.6,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          adminTestApp(
            AccountDecisionDialog(
              account: accountFixture,
              action: 'disable',
              repository: repo,
            ),
            scale: 1.6,
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(TextFormField));
        await tester.enterText(
          find.byType(TextFormField),
          'Nội dung xác minh hợp lệ.',
        );
        if (size.width < 600) {
          tester.view.viewInsets = const FakeViewPadding(bottom: 180);
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(find.byType(FilledButton).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
