import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/risk_reports/data/risk_report_repository.dart';
import 'package:delivery_app/features/risk_reports/widgets/risk_report_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  testWidgets('completes three steps and shows the report reference', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await _pumpLauncher(tester, repository: repository);

    await tester.tap(find.text('Mở báo cáo'));
    await tester.pumpAndSettle();
    expect(find.text('Báo cáo sự cố'), findsOneWidget);
    expect(find.text('Chọn vấn đề'), findsOneWidget);

    await tester.ensureVisible(find.text('Vấn đề an toàn'));
    await tester.tap(find.text('Vấn đề an toàn'));
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.text('Thêm thông tin'), findsOneWidget);
    expect(find.text('Thêm ảnh'), findsOneWidget);
    expect(find.text('Gửi vị trí hiện tại'), findsOneWidget);
    expect(find.text('Chọn tin nhắn liên quan'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'Khu vực giao hàng không an toàn.',
    );
    await tester.ensureVisible(find.text('Tiếp tục'));
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.text('Xác nhận báo cáo'), findsOneWidget);
    expect(find.text('Khu vực giao hàng không an toàn.'), findsOneWidget);

    await tester.ensureVisible(find.text('Gửi cho CSKH'));
    await tester.tap(find.text('Gửi cho CSKH'));
    await tester.pumpAndSettle();
    expect(repository.submitCalls, 1);
    expect(find.text('Mã báo cáo: report-123'), findsOneWidget);
  });

  testWidgets('back keeps selected reason and description', (tester) async {
    await _pumpLauncher(tester, repository: _FakeRepository());
    await tester.tap(find.text('Mở báo cáo'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Vấn đề an toàn'));
    await tester.tap(find.text('Vấn đề an toàn'));
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Khu vực giao hàng không an toàn.',
    );
    await tester.tap(find.text('Quay lại'));
    await tester.pumpAndSettle();

    final selected = tester.widget<Semantics>(
      find.byKey(const ValueKey('risk-option-safety')),
    );
    expect(selected.properties.selected, isTrue);
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.text('Khu vực giao hàng không an toàn.'), findsOneWidget);
  });

  testWidgets('fits a compact screen with large text', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpLauncher(
      tester,
      repository: _FakeRepository(),
      textScaler: const TextScaler.linear(1.6),
    );
    await tester.tap(find.text('Mở báo cáo'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Báo cáo sự cố'), findsOneWidget);
  });
}

Future<void> _pumpLauncher(
  WidgetTester tester, {
  required ParticipantRiskReportRepository repository,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: _Launcher(repository: repository),
      ),
    ),
  );
}

class _Launcher extends StatefulWidget {
  const _Launcher({required this.repository});

  final ParticipantRiskReportRepository repository;

  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  RiskReportSubmissionResult? result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: result == null
            ? TextButton(
                onPressed: () async {
                  final value = await showRiskReportSheet(
                    context,
                    order: _order,
                    role: RiskReporterRole.customer,
                    repository: widget.repository,
                  );
                  if (mounted) setState(() => result = value);
                },
                child: const Text('Mở báo cáo'),
              )
            : Text('Mã báo cáo: ${result!.reportId}'),
      ),
    );
  }
}

class _FakeRepository implements ParticipantRiskReportRepository {
  int submitCalls = 0;

  @override
  Future<RiskReportSubmissionResult> submit(
    ParticipantRiskReportDraft draft, {
    RiskReportProgressCallback? onProgress,
  }) async {
    submitCalls += 1;
    onProgress?.call(RiskReportSubmissionPhase.checkingDuplicate);
    onProgress?.call(RiskReportSubmissionPhase.processingImages);
    onProgress?.call(RiskReportSubmissionPhase.uploadingImages);
    onProgress?.call(RiskReportSubmissionPhase.sendingReport);
    return const RiskReportSubmissionResult(
      reportId: 'report-123',
      status: RiskStatus.open,
    );
  }
}

final _order = OrderModel(
  id: 'order-1',
  customerId: 'customer-1',
  driverId: 'driver-1',
  status: 'delivering',
  pickupAddress: 'Điểm lấy hàng',
  pickupLat: 10.7,
  pickupLng: 106.6,
  deliveryAddress: 'Điểm giao hàng',
  deliveryLat: 10.8,
  deliveryLng: 106.7,
  createdAt: DateTime(2026),
  trackingCode: 'GH123',
  deliveryFee: 30000,
  serviceType: 'standard',
  paymentMethod: 'cash',
  updatedAt: DateTime(2026),
);
