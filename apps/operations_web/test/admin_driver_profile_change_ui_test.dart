import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/admin/screens/drivers/profile_changes/widgets/admin_driver_profile_change_queue.dart';

import 'helpers/driver_profile_change_test_fixtures.dart';

void main() {
  testWidgets(
    'Admin sees a whole-request diff and rejection requires a reason',
    (tester) async {
      final repository = FakeAdminDriverProfileChangeRepository(
        requests: [pendingRequestFixture()],
      );
      await tester.pumpWidget(
        testApp(
          AdminDriverProfileChangeQueue(
            repository: repository,
            mediaResolver: FakeAdminDriverMediaResolver(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 thay đổi'), findsOneWidget);
      await tester.tap(find.text('Nguyễn Minh Tài'));
      await tester.pumpAndSettle();
      expect(find.text('0900000000'), findsOneWidget);
      expect(find.text('0911111111'), findsOneWidget);

      await tester.tap(find.text('Từ chối'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-profile-rejection')));
      await tester.pump();
      expect(repository.rejectCount, 0);
      expect(find.text('Vui lòng nhập lý do từ chối'), findsOneWidget);
    },
  );

  testWidgets('approval confirms and applies the whole request once', (
    tester,
  ) async {
    final repository = FakeAdminDriverProfileChangeRepository(
      requests: [pendingRequestFixture()],
    );
    await tester.pumpWidget(
      testApp(
        AdminDriverProfileChangeQueue(
          repository: repository,
          mediaResolver: FakeAdminDriverMediaResolver(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nguyễn Minh Tài'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Duyệt toàn bộ'));
    await tester.pumpAndSettle();
    expect(find.text('Duyệt toàn bộ yêu cầu?'), findsOneWidget);
    await tester.tap(find.text('Duyệt toàn bộ').last);
    await tester.pumpAndSettle();

    expect(repository.approveCount, 1);
  });

  testWidgets('realtime table change refreshes the queue once', (tester) async {
    final repository = FakeAdminDriverProfileChangeRepository(
      requests: [pendingRequestFixture()],
    );
    await tester.pumpWidget(
      testApp(
        AdminDriverProfileChangeQueue(
          repository: repository,
          mediaResolver: FakeAdminDriverMediaResolver(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.fetchCount, 1);

    repository.emitChange();
    await tester.pumpAndSettle();

    expect(repository.fetchCount, 2);
    await repository.dispose();
  });
}
