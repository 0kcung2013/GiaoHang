import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/admin/screens/drivers/widgets/admin_driver_registry_panel.dart';

import 'helpers/driver_profile_change_test_fixtures.dart';

void main() {
  testWidgets('registry panel renders existing driver approval states', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        AdminDriverRegistryPanel(
          drivers: [approvedDriverFixture()],
          loading: false,
          error: null,
          onRetry: () {},
          onOpenDriver: (_) {},
        ),
      ),
    );

    expect(find.text('Nguyễn Minh Tài'), findsOneWidget);
    expect(find.text('Đã duyệt'), findsOneWidget);
    expect(find.text('59-X1 123.45'), findsOneWidget);
  });
}
