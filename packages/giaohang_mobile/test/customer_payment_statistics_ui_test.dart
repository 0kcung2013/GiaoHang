import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_mobile/features/customer/screens/payments/customer_payment_statistics_screen.dart';
import 'package:giaohang_mobile/features/customer/screens/payments/models/customer_payment.dart';
import 'package:giaohang_mobile/features/customer/screens/payments/payment_strings.dart';
import 'package:giaohang_mobile/features/customer/screens/payments/providers/customer_payment_providers.dart';
import 'package:giaohang_mobile/features/customer/screens/payments/widgets/payment_transaction_tile.dart';

import 'helpers/customer_account_fixtures.dart'
    show loadCustomerAccountTestFonts;
import 'helpers/customer_payment_fixtures.dart';

void main() {
  setUpAll(() async {
    await loadCustomerAccountTestFonts();
    final font = File.fromUri(
      File(
        Platform.resolvedExecutable,
      ).parent.uri.resolve('../../material_fonts/MaterialIcons-Regular.otf'),
    );
    await (FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync()))))
        .load();
  });

  testWidgets(
    'method and period controls update totals; chart values can be inspected',
    (tester) async {
      final repository = FakeCustomerPaymentRepository();
      await _pump(tester, repository);
      expect(_total(tester), '280.000đ');
      await tester.tap(find.text(PaymentStrings.vnpay).first);
      await tester.pumpAndSettle();
      expect(_total(tester), '167.000đ');
      expect(
        repository.calls,
        1,
        reason: 'method filtering uses the complete period snapshot',
      );
      await tester.tap(find.text(PaymentStrings.day));
      await tester.pumpAndSettle();
      expect(_total(tester), '62.000đ');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('payment-bar-2')).hitTestable(),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('payment-bar-2')));
      await tester.pumpAndSettle();
      expect(find.text('12h · 62.000đ'), findsOneWidget);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 2000),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip(PaymentStrings.previous));
      await tester.pumpAndSettle();
      expect(find.text(PaymentStrings.empty), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'loading and errors do not show a misleading zero or partial total',
    (tester) async {
      final pending = Completer<List<CustomerPayment>>();
      final repository = FakeCustomerPaymentRepository()
        ..onFetch = (_) => pending.future;
      await _pump(tester, repository, settle: false);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byKey(const Key('payment-total')), findsNothing);
      pending.completeError(Exception('Offline'));
      await tester.pumpAndSettle();
      expect(find.text(PaymentStrings.loadError), findsOneWidget);
      expect(find.byKey(const Key('payment-total')), findsNothing);
      repository.onFetch = null;
      await tester.tap(find.text(PaymentStrings.retry));
      await tester.pumpAndSettle();
      expect(_total(tester), '280.000đ');
    },
  );

  testWidgets(
    'the calculation definition and payment reference are reviewable',
    (tester) async {
      await _pump(tester, FakeCustomerPaymentRepository());
      await tester.tap(find.byTooltip(PaymentStrings.explanation));
      await tester.pumpAndSettle();
      expect(find.text(PaymentStrings.calculation), findsOneWidget);
      await tester.tap(find.text(PaymentStrings.close));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('wallet:wallet-held')).hitTestable(),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PaymentTransactionTile).first);
      await tester.pumpAndSettle();
      expect(find.text(PaymentStrings.reference), findsOneWidget);
      expect(find.text('wallet-held'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final viewport in [
    (name: '390', size: const Size(390, 844), scale: 1.0),
    (name: '320_large_text', size: const Size(320, 568), scale: 1.6),
    (name: 'landscape', size: const Size(844, 390), scale: 1.6),
    (name: 'wide', size: const Size(1280, 800), scale: 1.0),
  ]) {
    testWidgets(
      'statistics fit ${viewport.name} and transactions remain reachable',
      (tester) async {
        tester.view.physicalSize = viewport.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _pump(
          tester,
          FakeCustomerPaymentRepository(),
          scale: viewport.scale,
        );
        expect(tester.takeException(), isNull);
        await _preview(tester, viewport.name);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('wallet:wallet-held')).hitTestable(),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.byKey(const ValueKey('wallet:wallet-held')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

String _total(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('payment-total'))).semanticsLabel!;

Future<void> _pump(
  WidgetTester tester,
  FakeCustomerPaymentRepository repository, {
  double scale = 1,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        customerPaymentRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        initialRoute: '/statistics',
        routes: {
          '/': (_) => const Scaffold(),
          '/statistics': (_) => RepaintBoundary(
            key: const Key('payment-preview'),
            child: CustomerPaymentStatisticsScreen(
              today: DateTime(2026, 10, 27),
            ),
          ),
        },
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Future<void> _preview(WidgetTester tester, String name) async {
  final directory = Platform.environment['PAYMENT_PREVIEW_DIR'];
  if (directory == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('payment-preview')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/customer_payments_$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
  });
}
