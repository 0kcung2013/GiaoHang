import 'dart:typed_data';

import 'package:delivery_app/features/risk_reports/controllers/risk_report_form_controller.dart';
import 'package:delivery_app/features/risk_reports/data/risk_report_repository.dart';
import 'package:delivery_app/features/risk_reports/utils/risk_report_options.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  test('shows role-aware reasons without exposing internal severity', () {
    final customer = riskOptionsFor(RiskReporterRole.customer);
    final driver = riskOptionsFor(RiskReporterRole.driver);

    expect(
      customer.map((option) => option.category),
      contains(RiskCategory.deliveryDelay),
    );
    expect(
      customer.map((option) => option.category),
      isNot(contains(RiskCategory.suspiciousAddress)),
    );
    expect(
      driver.map((option) => option.category),
      contains(RiskCategory.suspiciousAddress),
    );
    expect(
      driver.map((option) => option.category),
      contains(RiskCategory.cargoIssue),
    );
  });

  test('validates each step and preserves values when navigating back', () {
    final controller = RiskReportFormController(
      orderId: 'order-1',
      repository: _FakeRepository(),
    );

    expect(controller.next(), isFalse);
    expect(controller.state.categoryError, isNotNull);

    controller.selectCategory(RiskCategory.safety);
    expect(controller.next(), isTrue);
    controller.setDescription('Qua ngan');
    expect(controller.next(), isFalse);
    expect(controller.state.descriptionError, isNotNull);

    controller.setDescription('Khu vực giao hàng không an toàn.');
    controller.setPhotos(List.generate(6, _photo));
    expect(controller.next(), isFalse);
    expect(controller.state.photoError, isNotNull);

    controller.setPhotos([_photo(0)]);
    expect(controller.next(), isTrue);
    controller.back();
    controller.back();
    expect(controller.state.category, RiskCategory.safety);
    expect(controller.state.description, 'Khu vực giao hàng không an toàn.');
    expect(controller.state.photos, hasLength(1));
  });

  test('suppresses duplicate submit and retains state for retry', () async {
    final repository = _FakeRepository(failFirst: true);
    final controller = RiskReportFormController(
      orderId: 'order-1',
      repository: repository,
    );
    controller.selectCategory(RiskCategory.cargoIssue);
    controller.next();
    controller.setDescription('Kiện hàng bị rách trước khi giao.');
    controller.next();

    await Future.wait([controller.submit(), controller.submit()]);
    expect(repository.submitCalls, 1);
    expect(controller.state.category, RiskCategory.cargoIssue);
    expect(controller.state.description, isNotEmpty);
    expect(controller.state.errorMessage, isNotNull);

    final result = await controller.submit();
    expect(repository.submitCalls, 2);
    expect(result?.reportId, 'report-2');
    expect(controller.state.result, same(result));
  });
}

RiskPhotoInput _photo(int index) => RiskPhotoInput(
  fileName: 'photo-$index.png',
  bytes: Uint8List.fromList([index, 1, 2]),
);

class _FakeRepository implements ParticipantRiskReportRepository {
  _FakeRepository({this.failFirst = false});

  final bool failFirst;
  int submitCalls = 0;

  @override
  Future<RiskReportSubmissionResult> submit(
    ParticipantRiskReportDraft draft, {
    RiskReportProgressCallback? onProgress,
  }) async {
    submitCalls += 1;
    onProgress?.call(RiskReportSubmissionPhase.checkingDuplicate);
    onProgress?.call(RiskReportSubmissionPhase.sendingReport);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    if (failFirst && submitCalls == 1) {
      throw const RiskReportRepositoryException(
        code: RiskReportErrorCode.uploadFailed,
        userMessage: 'Không thể tải ảnh lên.',
      );
    }
    return RiskReportSubmissionResult(
      reportId: 'report-$submitCalls',
      status: RiskStatus.open,
    );
  }
}
