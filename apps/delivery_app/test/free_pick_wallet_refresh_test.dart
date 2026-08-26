import 'package:delivery_app/core/services/free_pick_service.dart';
import 'package:delivery_app/features/driver/screens/free_pick/utils/free_pick_wallet_refresh.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const viewport = FreePickViewport(
    south: 10.7,
    west: 106.6,
    north: 10.9,
    east: 106.8,
  );

  test('reloads the last viewport when the wallet revision advances', () {
    FreePickViewport? reloadedViewport;

    final didReload = reloadFreePickAfterWalletChange(
      previousRevision: 1,
      nextRevision: 2,
      isEnabled: true,
      viewport: viewport,
      reload: (value) => reloadedViewport = value,
    );

    expect(didReload, isTrue);
    expect(reloadedViewport, same(viewport));
  });

  test('ignores the initial wallet snapshot', () {
    var reloadCount = 0;

    final didReload = reloadFreePickAfterWalletChange(
      previousRevision: null,
      nextRevision: 1,
      isEnabled: true,
      viewport: viewport,
      reload: (_) => reloadCount++,
    );

    expect(didReload, isFalse);
    expect(reloadCount, 0);
  });
}
