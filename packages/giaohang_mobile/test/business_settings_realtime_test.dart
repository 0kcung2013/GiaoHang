import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_config/giaohang_config.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/utils/order_settings_review.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/order_settings_changed_notice.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/submit_order_button.dart';
import 'package:giaohang_mobile/features/driver/screens/earnings/widgets/wallet_topup_sheet.dart';

import 'helpers/customer_account_fixtures.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  setUpAll(() async {
    await loadCustomerAccountTestFonts();
    final iconFile = File.fromUri(
      File(
        Platform.resolvedExecutable,
      ).parent.uri.resolve('../../material_fonts/materialicons-regular.otf'),
    );
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(iconFile.readAsBytesSync())));
    await loader.load();
  });

  test(
    'change during initial fetch queues one fetch without overlapping requests',
    () async {
      final changes = StreamController<void>(sync: true);
      final requests = <Completer<int>>[];
      final values = <int>[];
      final subscription = refreshOnChanges(changes.stream, () {
        final request = Completer<int>();
        requests.add(request);
        return request.future;
      }).listen(values.add);
      expect(changes.hasListener, isTrue);
      changes.add(null);
      changes.add(null);
      expect(requests.length, 1);
      requests[0].complete(1);
      await flush();
      expect(requests.length, 2);
      requests[1].complete(2);
      await flush();
      expect(values, [1, 2]);
      await subscription.cancel();
      await changes.close();
    },
  );

  test(
    'an API failure keeps listening and the next reconnect signal recovers',
    () async {
      final changes = StreamController<void>();
      var attempts = 0;
      final values = <int>[];
      final errors = <Object>[];
      final subscription = refreshOnChanges(changes.stream, () async {
        if (++attempts == 1) throw StateError('offline');
        return 7;
      }).listen(values.add, onError: errors.add);
      await flush();
      expect(errors.length, 1);
      changes.add(null);
      await flush();
      expect(values, [7]);
      await subscription.cancel();
      await changes.close();
    },
  );

  test(
    'closing a screen unsubscribes and discards a late HTTP response',
    () async {
      final changes = StreamController<void>();
      final request = Completer<int>();
      final values = <int>[];
      final subscription = refreshOnChanges(
        changes.stream,
        () => request.future,
      ).listen(values.add);
      await subscription.cancel();
      expect(changes.hasListener, isFalse);
      request.complete(9);
      await flush();
      expect(values, isEmpty);
      await changes.close();
    },
  );

  test(
    'unpaid quotes require review; issued or unresolved payments retain their snapshot',
    () {
      expect(
        requiresOrderSettingsReview(quotedRevision: 3, latestRevision: 4),
        isTrue,
      );
      expect(
        requiresOrderSettingsReview(quotedRevision: 4, latestRevision: 4),
        isFalse,
      );
      expect(
        requiresOrderSettingsReview(quotedRevision: null, latestRevision: 4),
        isTrue,
      );
      expect(
        requiresOrderSettingsReview(
          quotedRevision: 3,
          latestRevision: 4,
          paymentProtected: true,
        ),
        isFalse,
      );
      expect(
        requiresOrderSettingsReview(
          quotedRevision: 4,
          latestRevision: 4,
          rejectedByServer: true,
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'live topup limits preserve the typed amount and invalidate it until corrected',
    (tester) async {
      final updates = StreamController<BusinessSettings>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showWalletTopupSheet(
                  context,
                  settings: BusinessSettings(revision: 1),
                  updates: updates.stream,
                ),
                child: const Text('Nạp thử'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Nạp thử'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '300.000');
      updates.add(BusinessSettings(revision: 2, values: {'topup_min': 500000}));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '300.000',
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.textContaining('500.000đ –'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '600.000');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(updates.hasListener, isFalse);
      await tester.runAsync(() => updates.close());
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );

  for (final width in [320.0, 390.0]) {
    testWidgets(
      'quote change notice and action fit ${width}px with enlarged text',
      (tester) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 700),
                textScaler: const TextScaler.linear(1.6),
              ),
              child: RepaintBoundary(
                key: key,
                child: Scaffold(
                  bottomNavigationBar: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const OrderSettingsChangedNotice(),
                      SubmitOrderButton(
                        label: OrderSettingsChangedNotice.action,
                        subtitle: '',
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(OrderSettingsChangedNotice.action), findsOneWidget);
        if (Platform.environment['BUSINESS_SETTINGS_SCREENSHOT'] == '1') {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final rendered = await boundary.toImage();
            final bytes = await rendered.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('.tmp/settings-realtime-${width.toInt()}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            rendered.dispose();
          });
        }
      },
    );
  }
}
