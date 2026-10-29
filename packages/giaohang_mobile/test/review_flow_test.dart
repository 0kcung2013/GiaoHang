import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/core/models/review_model.dart';
import 'package:giaohang_mobile/core/providers/customer_providers.dart';
import 'package:giaohang_mobile/core/services/review_service.dart';
import 'package:giaohang_mobile/features/reviews/review_strings.dart';
import 'package:giaohang_mobile/features/reviews/widgets/review_form_sheet.dart';
import 'package:giaohang_mobile/features/reviews/widgets/submit_review_sheet.dart';
import 'package:giaohang_mobile/features/reviews/widgets/driver_rate_customer_sheet.dart';
import 'package:giaohang_mobile/features/reviews/widgets/order_review_section.dart';

import 'review_service_test.dart' show reviewTestClient, reviewRow, response;

final reviewOrder = OrderModel(
  id: 'order-1',
  customerId: 'actor-1',
  driverId: 'driver-1',
  status: 'delivered',
  pickupAddress: 'Điểm lấy',
  pickupLat: 10,
  pickupLng: 106,
  deliveryAddress: 'Điểm giao',
  deliveryLat: 10.1,
  deliveryLng: 106.1,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  trackingCode: 'GH-10220',
  deliveryFee: 20000,
  serviceType: 'standard',
  paymentMethod: 'cash',
);

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final bytes = File.fromUri(
      File(
        Platform.resolvedExecutable,
      ).parent.uri.resolve('../../material_fonts/roboto-regular.ttf'),
    ).readAsBytesSync();
    const names = ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key == 'AssetManifest.bin') {
            return const StandardMessageCodec().encodeMessage({
              for (final weight in names)
                'PlusJakartaSans-$weight.ttf': [
                  {'asset': 'PlusJakartaSans-$weight.ttf'},
                ],
            });
          }
          if (key.endsWith('.ttf')) return ByteData.sublistView(bytes);
          return null;
        });
    for (final weight in [
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
    ]) {
      GoogleFonts.plusJakartaSans(fontWeight: weight);
    }
    await GoogleFonts.pendingFonts();
  });

  testWidgets(
    'pending submission blocks duplicate sends and back, then succeeds',
    (tester) async {
      final pending = Completer<http.Response>();
      http.Request? write;
      var writes = 0;
      final client = await _reviewClient((r) {
        if (!r.url.path.contains('/rpc/')) return response(r, []);
        writes++;
        write = r;
        return pending.future;
      });
      addTearDown(() => tester.runAsync(client.dispose));
      await _pump(tester, client);
      await _open(tester);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, ReviewStrings.submit),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('5 sao'));
      await tester.enterText(find.byType(TextField), 'Giữ nguyên nhận xét');
      await tester.ensureVisible(find.text(ReviewStrings.submit));
      await tester.tap(find.text(ReviewStrings.submit));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ReviewFormSheet), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, ReviewStrings.skip),
            )
            .onPressed,
        isNull,
      );
      expect(writes, 1);
      pending.complete(
        response(write!, {
          'review_id': 'review-1',
          'direction': 'customer_to_driver',
          'rating': 5,
        }),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ReviewFormSheet), findsNothing);
      expect(find.text(ReviewStrings.success), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'network failure keeps draft, allows retry, and does not leak server error',
    (tester) async {
      var writes = 0;
      final client = await _reviewClient((r) {
        if (!r.url.path.contains('/rpc/')) return response(r, []);
        writes++;
        return writes == 1
            ? response(r, {
                'code': 'XX000',
                'message': 'secret SQL detail',
              }, 500)
            : response(r, {
                'review_id': 'review-1',
                'direction': 'customer_to_driver',
                'rating': 4,
              });
      });
      addTearDown(() => tester.runAsync(client.dispose));
      await _pump(tester, client);
      await _open(tester);
      await tester.tap(find.byTooltip('4 sao'));
      await tester.enterText(find.byType(TextField), 'Nội dung cần giữ');
      await tester.ensureVisible(find.text(ReviewStrings.submit));
      await tester.tap(find.text(ReviewStrings.submit));
      await tester.pumpAndSettle();
      expect(find.text(ReviewService.submitError), findsOneWidget);
      expect(find.textContaining('secret SQL'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Nội dung cần giữ',
      );
      await tester.ensureVisible(find.text(ReviewStrings.submit));
      await tester.tap(find.text(ReviewStrings.submit));
      await tester.pumpAndSettle();
      expect(writes, 2);
      expect(find.text(ReviewStrings.success), findsOneWidget);
    },
  );

  testWidgets('disposed pending form ignores later failure', (tester) async {
    final pending = Completer<http.Response>();
    http.Request? write;
    final client = await _reviewClient((r) {
      if (!r.url.path.contains('/rpc/')) return response(r, []);
      write = r;
      return pending.future;
    });
    addTearDown(() => tester.runAsync(client.dispose));
    await _pump(tester, client);
    await _open(tester);
    await tester.tap(find.byTooltip('1 sao'));
    await tester.pump();
    await tester.ensureVisible(find.text(ReviewStrings.submit));
    await tester.tap(find.text(ReviewStrings.submit));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    pending.complete(response(write!, {'message': 'offline'}, 503));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a stalled request times out, preserves the draft, and ignores a late reply',
    (tester) async {
      final pending = Completer<http.Response>();
      http.Request? write;
      final client = await _reviewClient((r) {
        if (!r.url.path.contains('/rpc/')) return response(r, []);
        write = r;
        return pending.future;
      });
      addTearDown(() => tester.runAsync(client.dispose));
      await _pump(tester, client);
      await _open(tester);
      await tester.tap(find.byTooltip('2 sao'));
      await tester.enterText(find.byType(TextField), 'Nhận xét chờ gửi');
      await tester.ensureVisible(find.text(ReviewStrings.submit));
      await tester.tap(find.text(ReviewStrings.submit));
      await tester.pump();
      await tester.pump(
        ReviewService.requestTimeout + const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(find.text(ReviewService.submitError), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Nhận xét chờ gửi',
      );
      pending.complete(
        response(write!, {
          'review_id': 'review-1',
          'direction': 'customer_to_driver',
          'rating': 2,
        }),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ReviewFormSheet), findsOneWidget);
      expect(find.text(ReviewStrings.success), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'driver lookup failure is handled, and repeated taps open one sheet',
    (tester) async {
      var reads = 0;
      final client = await _reviewClient((r) {
        reads++;
        return reads == 1
            ? response(r, {'message': 'offline'}, 500)
            : response(r, []);
      });
      addTearDown(() => tester.runAsync(client.dispose));
      await _pump(tester, client, driver: true);
      await _open(tester);
      expect(find.text(ReviewService.loadError), findsOneWidget);
      await tester.tap(find.text('Mở đánh giá'));
      await tester.tap(find.text('Mở đánh giá'));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.byType(ReviewFormSheet), findsOneWidget);
      expect(find.text(ReviewStrings.customerTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an existing driver review is not offered for submission again', (
    tester,
  ) async {
    final client = await _reviewClient(
      (r) =>
          response(r, [reviewRow(direction: ReviewDirection.driverToCustomer)]),
    );
    addTearDown(() => tester.runAsync(client.dispose));
    await _pump(tester, client, driver: true);
    await _open(tester);
    expect(find.byType(ReviewFormSheet), findsNothing);
    expect(find.text(ReviewStrings.alreadyRecorded), findsOneWidget);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(1280, 800),
  ]) {
    testWidgets(
      'form remains scrollable at $size with large text and keyboard',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final client = await _reviewClient((r) => response(r, []));
        addTearDown(() => tester.runAsync(client.dispose));
        await _pump(tester, client, scale: 1.6);
        await _open(tester);
        await tester.tap(find.byTooltip('3 sao'));
        await tester.ensureVisible(find.byType(TextField));
        await tester.tap(find.byType(TextField));
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(ReviewStrings.submit));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final sheet = tester.getRect(find.byType(ReviewFormSheet));
        expect(sheet.width, lessThanOrEqualTo(560));
        tester.view.resetViewInsets();
      },
    );
  }

  testWidgets('customer review status can be retried after a read error', (
    tester,
  ) async {
    var reads = 0;
    final client = await _reviewClient(
      (r) => ++reads == 1
          ? response(r, {'message': 'offline'}, 500)
          : response(r, []),
    );
    addTearDown(() => tester.runAsync(client.dispose));
    await _pump(tester, client, section: true, scale: 1.6);
    await tester.pumpAndSettle();
    await tester.tap(find.text(ReviewStrings.retry));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('Đánh giá ngay'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  SupabaseClient client, {
  bool driver = false,
  bool section = false,
  double scale = 1,
}) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      reviewServiceProvider.overrideWithValue(ReviewService(client: client)),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => section
              ? OrderReviewSection(order: reviewOrder)
              : Center(
                  child: ElevatedButton(
                    child: const Text('Mở đánh giá'),
                    onPressed: () {
                      if (driver) {
                        showDriverRateCustomerSheet(
                          context: context,
                          order: reviewOrder,
                        );
                      } else {
                        showSubmitReviewSheet(
                          context: context,
                          order: reviewOrder,
                        );
                      }
                    },
                  ),
                ),
        ),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Mở đánh giá'));
  await tester.pumpAndSettle();
}

Future<SupabaseClient> _reviewClient(
  FutureOr<http.Response> Function(http.Request) handle,
) async {
  final client = await TestWidgetsFlutterBinding.instance.runAsync(
    () => reviewTestClient(handle),
  );
  return client!;
}
