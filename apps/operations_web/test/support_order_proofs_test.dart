import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/support_orders/data/support_order_repository.dart';
import 'package:operations_web/features/support_orders/models/support_order.dart';
import 'package:operations_web/features/support_orders/models/support_order_proof.dart';
import 'package:operations_web/features/support_orders/widgets/support_order_proofs.dart';
import 'package:operations_web/features/support_orders/widgets/support_order_proof_image.dart';

import 'helpers/proof_image_http_client.dart';

void main() {
  testWidgets('renders signed photo bytes with image semantics', (
    tester,
  ) async {
    debugNetworkImageHttpClientProvider = () => ProofImageHttpClient();
    addTearDown(() => debugNetworkImageHttpClientProvider = null);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.runAsync(() async {
      await precacheImage(
        const NetworkImage('https://private.example.invalid/private/pickup'),
        tester.element(find.byType(SizedBox).first),
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: SupportOrderProofImage(
          loadUrl: () async => 'https://private.example.invalid/private/pickup',
          semanticLabel: 'Ảnh lấy hàng',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không thể tải ảnh'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(
      tester.widget<Image>(find.byType(Image)).semanticLabel,
      'Ảnh lấy hàng',
    );
    debugNetworkImageHttpClientProvider = null;
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'loads proofs once, shows stages and refreshes signed image URLs',
    (tester) async {
      final repository = ProofTestRepository();
      await _mount(tester, repository);
      expect(find.text('Ảnh lấy hàng'), findsOneWidget);
      expect(find.text('Ảnh giao hàng'), findsOneWidget);
      expect(find.text('Ảnh hoàn hàng'), findsOneWidget);
      expect(repository.fetchCount, 1);
      expect(repository.signCount, 3);

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      expect(repository.fetchCount, 1);

      await tester.tap(find.text('Tải lại ảnh'));
      await tester.pumpAndSettle();
      expect(repository.fetchCount, 2);
      expect(repository.signCount, 6);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('opens a zoomable viewer and retries an expired private URL', (
    tester,
  ) async {
    final repository = ProofTestRepository();
    await _mount(tester, repository);
    final before = repository.signCount;
    await tester.tap(find.text('Xem ảnh lớn').first);
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(repository.signCount, before + 1);

    await tester.tap(find.text('Thử lại').last);
    await tester.pumpAndSettle();
    expect(repository.signCount, before + 2);
    await tester.tap(find.byTooltip('Đóng ảnh'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets(
    'metadata error has a working reload and missing stages remain explicit',
    (tester) async {
      final repository = ProofTestRepository()..failFetch = true;
      await _mount(tester, repository);
      expect(find.text('Không thể tải danh sách ảnh.'), findsOneWidget);
      repository.failFetch = false;
      repository.proofs = [];
      await tester.tap(find.text('Tải lại ảnh'));
      await tester.pumpAndSettle();
      expect(find.text('Không thể tải danh sách ảnh.'), findsNothing);
      expect(find.text('Chưa có ảnh được hiển thị'), findsNWidgets(2));
      expect(find.text('Ảnh hoàn hàng'), findsNothing);
      expect(repository.signCount, 0);
      repository.failFetch = true;
      await tester.tap(find.text('Tải lại ảnh'));
      await tester.pumpAndSettle();
      expect(find.text('Không thể tải danh sách ảnh.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('does not show empty state while proof metadata is loading', (
    tester,
  ) async {
    final pending = Completer<List<SupportOrderProof>>();
    final repository = ProofTestRepository()..pending = pending.future;
    await tester.pumpWidget(_app(repository));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Chưa có ảnh được hiển thị'), findsNothing);
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('short narrow viewport supports large text and scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(ProofTestRepository(), textScale: 1.6));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Ảnh hoàn hàng'), 250);
    expect(find.text('Ảnh hoàn hàng').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _mount(WidgetTester tester, ProofTestRepository repository) async {
  tester.view.physicalSize = const Size(1100, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_app(repository));
  await tester.pumpAndSettle();
}

Widget _app(ProofTestRepository repository, {double textScale = 1}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: SupportOrderProofs(
              orderId: 'order-1',
              repository: repository,
            ),
          ),
        ),
      ),
    );

class ProofTestRepository implements SupportOrderRepository {
  List<SupportOrderProof> proofs = [
    for (final stage in ['pickup', 'delivery', 'return'])
      SupportOrderProof(
        stage: stage,
        storagePath: 'private/$stage',
        capturedAt: DateTime(2026, 10, 19, 10, 30),
      ),
  ];
  int fetchCount = 0;
  int signCount = 0;
  bool failFetch = false;
  Future<List<SupportOrderProof>>? pending;

  @override
  Future<List<SupportOrderProof>> fetchDeliveryProofs(String orderId) async {
    fetchCount++;
    if (failFetch) throw StateError('Permission denied');
    return pending ?? proofs;
  }

  @override
  Future<String> resolveDeliveryProofUrl(String storagePath) async {
    signCount++;
    throw StateError('Signed URL unavailable');
  }

  @override
  Future<List<SupportOrder>> fetchOrders({String trackingCode = ''}) async =>
      [];

  @override
  Future<List<SupportOrderStatusLog>> fetchStatusLogs(String orderId) async =>
      [];
}
