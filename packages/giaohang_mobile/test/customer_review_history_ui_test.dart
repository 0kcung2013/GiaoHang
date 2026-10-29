import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_mobile/features/reviews/history/customer_review_history_screen.dart';
import 'package:giaohang_mobile/features/reviews/history/models/review_history_entry.dart';
import 'package:giaohang_mobile/features/reviews/history/providers/review_history_provider.dart';
import 'package:giaohang_mobile/features/reviews/history/review_history_strings.dart';
import 'package:giaohang_mobile/features/reviews/history/widgets/review_history_card.dart';
import 'package:giaohang_mobile/features/reviews/history/widgets/review_history_states.dart';

import 'helpers/customer_account_fixtures.dart'
    show loadCustomerAccountTestFonts;
import 'helpers/review_history_fixtures.dart';

void main() {
  setUpAll(() async {
    await loadCustomerAccountTestFonts();
    final icons = File.fromUri(
      File(
        Platform.resolvedExecutable,
      ).parent.uri.resolve('../../material_fonts/MaterialIcons-Regular.otf'),
    );
    await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
        .load();
  });

  testWidgets(
    'filters reviews, shows filtered empty state, and clears the filter',
    (tester) async {
      final repository = FakeReviewHistoryRepository();
      await _pump(tester, repository);
      expect(find.byType(ReviewHistoryCard), findsNWidgets(2));
      expect(find.text('Đúng giờ'), findsOneWidget);
      expect(find.text('Cẩn thận với hàng'), findsOneWidget);
      await tester.tap(find.text('1 sao'));
      await tester.pumpAndSettle();
      expect(find.text(ReviewHistoryStrings.filteredEmpty), findsOneWidget);
      expect(repository.calls.last.rating, 1);
      await tester.tap(find.text(ReviewHistoryStrings.clearFilter));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewHistoryCard), findsNWidgets(2));
      expect(repository.calls.last.rating, isNull);
    },
  );

  testWidgets('loading, error, retry, and empty states are distinct', (
    tester,
  ) async {
    final pending = Completer<List<ReviewHistoryEntry>>();
    final repository = FakeReviewHistoryRepository()
      ..onFetch = (_, _) => pending.future;
    await _pump(tester, repository, settle: false);
    expect(find.byType(ReviewHistoryLoading), findsOneWidget);
    expect(find.text(ReviewHistoryStrings.emptyTitle), findsNothing);
    pending.completeError(Exception('Offline'));
    await tester.pumpAndSettle();
    expect(find.text(ReviewHistoryStrings.loadError), findsOneWidget);
    repository.onFetch = (_, _) async => [];
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text(ReviewHistoryStrings.emptyTitle), findsOneWidget);
    expect(find.text(ReviewHistoryStrings.orderHistory), findsOneWidget);
  });

  for (final viewport in [
    (name: '390', size: const Size(390, 844), scale: 1.0),
    (name: '320_large_text', size: const Size(320, 568), scale: 1.6),
    (name: 'landscape', size: const Size(844, 390), scale: 1.6),
    (name: 'wide', size: const Size(1280, 800), scale: 1.0),
  ]) {
    testWidgets(
      'history fits ${viewport.name} and order action stays reachable',
      (tester) async {
        tester.view.physicalSize = viewport.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _pump(
          tester,
          FakeReviewHistoryRepository(),
          scale: viewport.scale,
        );
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('review-order-review-0')).hitTestable(),
          180,
        );
        expect(
          find.byKey(const ValueKey('review-order-review-0')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView), const Offset(0, 2000));
        await tester.pumpAndSettle();
        await _preview(tester, viewport.name);
      },
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  FakeReviewHistoryRepository repository, {
  double scale = 1,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reviewHistoryRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        initialRoute: '/reviews',
        routes: {
          '/': (_) => const Scaffold(),
          '/reviews': (_) => const RepaintBoundary(
            key: Key('review-preview'),
            child: CustomerReviewHistoryScreen(),
          ),
        },
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Future<void> _preview(WidgetTester tester, String name) async {
  final directory = Platform.environment['REVIEW_PREVIEW_DIR'];
  if (directory == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('review-preview')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/customer_reviews_$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
  });
}
