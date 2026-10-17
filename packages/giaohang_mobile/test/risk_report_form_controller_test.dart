import 'dart:typed_data';

import 'package:giaohang_mobile/features/risk_reports/controllers/risk_report_form_controller.dart';
import 'package:giaohang_mobile/features/risk_reports/data/risk_report_repository.dart';
import 'package:giaohang_mobile/features/risk_reports/utils/risk_report_options.dart';
import 'package:giaohang_mobile/features/risk_reports/utils/risk_recipient_return_request.dart';
import 'package:giaohang_mobile/features/risk_reports/utils/risk_report_strings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  test(
    'cargo cancellation requires a photo and keeps one submission',
    () async {
      final repository = _FakeRepository();
      final controller = RiskReportFormController(
        orderId: 'order-1',
        repository: repository,
        requireCargoEvidence: true,
        allowedCategories: {
          RiskCategory.cargoIssue,
          RiskCategory.contactIssue,
          RiskCategory.other,
        },
      );
      addTearDown(controller.dispose);
      controller.selectCategory(RiskCategory.cargoIssue);
      controller.setDescription('Kiện hàng lớn hơn kích thước đã khai báo.');
      expect(await controller.submit(), isNull);
      expect(controller.state.photoError, RiskReportStrings.cargoPhotoRequired);
      controller.setPhotos([_photo(0)]);
      await Future.wait([controller.submit(), controller.submit()]);
      expect(repository.submitCalls, 1);
      expect(repository.lastDraft?.category, RiskCategory.cargoIssue);
      expect(repository.lastDraft?.photos, hasLength(1));
      expect(
        repository.lastDraft?.latitude,
        isNull,
        reason: 'GPS is supplemental, not another manual requirement',
      );
    },
  );
  test(
    'stale category cannot submit outside the current stage options',
    () async {
      final repository = _FakeRepository();
      final controller = RiskReportFormController(
        orderId: 'order-1',
        repository: repository,
        requireCargoEvidence: true,
        allowedCategories: {RiskCategory.contactIssue, RiskCategory.other},
      );
      addTearDown(controller.dispose);
      controller.selectCategory(RiskCategory.cargoIssue);
      controller.setPhotos([_photo(0)]);
      controller.setDescription('Đã nhận hàng nhưng yêu cầu hủy.');
      expect(await controller.submit(), isNull);
      expect(
        controller.state.categoryError,
        RiskReportStrings.reasonUnavailable,
      );
      expect(repository.submitCalls, 0);
    },
  );
  test(
    'recipient report requires call screenshots and confirmed server wait',
    () async {
      var allowed = false;
      final repository = _FakeRepository();
      final controller = RiskReportFormController(
        orderId: 'order-1',
        repository: repository,
        requireRecipientEvidence: true,
        canReportRecipient: () async => allowed,
      );
      controller.selectCategory(RiskCategory.contactIssue);
      controller.next();
      controller.setDescription('Khách không nghe máy sau ba lần gọi.');
      expect(controller.next(), isFalse);
      expect(controller.state.photoError, isNotNull);
      expect(await controller.submit(), isNull);
      expect(repository.submitCalls, 0);
      controller.setPhotos([_photo(0)]);
      expect(
        controller.next(),
        isTrue,
        reason: 'One screenshot can show three calls',
      );
      expect(await controller.submit(), isNull);
      expect(repository.submitCalls, 0);
      allowed = true;
      expect(await controller.submit(), isNotNull);
      expect(repository.submitCalls, 1);
      expect(
        repository.lastDraft?.description,
        RiskRecipientReturnRequest.describe(
          'Khách không nghe máy sau ba lần gọi.',
        ),
      );
      expect(repository.lastDraft?.category, RiskCategory.contactIssue);
      expect(repository.lastDraft?.photos, hasLength(1));
      expect(
        controller.state.description,
        'Khách không nghe máy sau ba lần gọi.',
      );
      controller.dispose();
    },
  );

  for (final category in [
    RiskCategory.safety,
    RiskCategory.suspiciousAddress,
    RiskCategory.cargoIssue,
    RiskCategory.payment,
  ]) {
    test(
      '$category reports immediately without recipient wait or return request',
      () async {
        final repository = _FakeRepository();
        var permissionChecks = 0;
        final controller = RiskReportFormController(
          orderId: 'order-1',
          repository: repository,
          requireRecipientEvidence: true,
          canReportRecipient: () async {
            permissionChecks++;
            return false;
          },
        );
        addTearDown(controller.dispose);
        controller.selectCategory(category);
        controller.setDescription('Sự cố cần CSKH hướng dẫn xử lý ngay.');
        expect(await controller.checkRecipientWait(), isTrue);
        expect(await controller.submit(), isNotNull);
        expect(permissionChecks, 0);
        expect(repository.lastDraft?.description, controller.state.description);
        expect(controller.requestsRecipientReturn, isFalse);
      },
    );
  }

  test(
    'customer or pickup contact report does not request a delivery return',
    () async {
      final repository = _FakeRepository();
      final controller = RiskReportFormController(
        orderId: 'order-1',
        repository: repository,
      );
      addTearDown(controller.dispose);
      controller.selectCategory(RiskCategory.contactIssue);
      controller.setDescription('Không liên lạc được với tài xế.');
      expect(await controller.submit(), isNotNull);
      expect(
        repository.lastDraft?.description,
        'Không liên lạc được với tài xế.',
      );
      expect(controller.requestsRecipientReturn, isFalse);
    },
  );

  test(
    'combined report retries without duplicating the return request',
    () async {
      final repository = _FakeRepository(failFirst: true);
      final controller = RiskReportFormController(
        orderId: 'order-1',
        repository: repository,
        requireRecipientEvidence: true,
        canReportRecipient: () async => true,
      );
      addTearDown(controller.dispose);
      controller.selectCategory(RiskCategory.contactIssue);
      controller.setDescription('Khách không nghe máy sau ba lần gọi.');
      controller.setPhotos([_photo(0)]);
      await Future.wait([controller.submit(), controller.submit()]);
      expect(repository.submitCalls, 1);
      expect(controller.state.result, isNull);
      expect(await controller.submit(), isNotNull);
      expect(repository.submitCalls, 2);
      expect(
        repository.lastDraft?.description,
        RiskRecipientReturnRequest.describe(controller.state.description),
      );
    },
  );

  test(
    'combined description fits existing limit without truncating driver notes',
    () async {
      final repository = _FakeRepository();
      final controller = RiskReportFormController(
        orderId: 'order-1',
        repository: repository,
        requireRecipientEvidence: true,
        canReportRecipient: () async => true,
      );
      addTearDown(controller.dispose);
      controller.selectCategory(RiskCategory.contactIssue);
      controller.setPhotos([_photo(0)]);
      controller.setDescription('x' * (controller.descriptionLimit + 1));
      expect(await controller.submit(), isNull);
      expect(repository.submitCalls, 0);
      expect(controller.state.descriptionError, isNotNull);
      controller.setDescription('x' * controller.descriptionLimit);
      expect(await controller.submit(), isNotNull);
      expect(repository.lastDraft?.description.length, 4000);
      expect(
        repository.lastDraft?.description.endsWith(
          controller.state.description,
        ),
        isTrue,
      );
    },
  );

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
      isNot(contains(RiskCategory.suspiciousAddress)),
    );
    expect(
      driver.map((option) => option.category),
      contains(RiskCategory.cargoIssue),
    );
    expect(driver, hasLength(3));
    final picked = riskOptionsFor(
      RiskReporterRole.driver,
      orderStatus: 'picking_up',
      hasPickedUp: true,
    );
    expect(
      picked.map((option) => option.category),
      isNot(contains(RiskCategory.cargoIssue)),
    );
    expect(
      picked.map((option) => option.label),
      contains(RiskReportStrings.deliveryUnavailable),
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

  test('freezes the initial driver location in the submitted report', () async {
    final repository = _FakeRepository();
    final controller = RiskReportFormController(
      orderId: 'order-1',
      repository: repository,
      initialLatitude: 11.0308,
      initialLongitude: 106.62202,
    );
    controller.selectCategory(RiskCategory.safety);
    controller.next();
    controller.setDescription('Receiver is unavailable at delivery point.');
    controller.next();

    await controller.submit();

    expect(repository.lastDraft?.latitude, 11.0308);
    expect(repository.lastDraft?.longitude, 106.62202);
    expect(repository.lastDraft?.locationCapturedAt, isNotNull);
  });

  test('driver report cannot continue without sharing current location', () {
    final controller = RiskReportFormController(
      orderId: 'order-1',
      repository: _FakeRepository(),
      requireLocation: true,
    );
    controller.selectCategory(RiskCategory.safety);
    expect(controller.next(), isTrue);
    controller.setDescription('Khách không nghe máy tại điểm giao hàng.');

    expect(controller.next(), isFalse);
    expect(controller.state.locationError, isNotNull);

    controller.setLocation(
      latitude: 10.821,
      longitude: 106.721,
      address: '123 Đường DX 124, Tân An, Thành phố Hồ Chí Minh',
    );
    expect(controller.next(), isTrue);
    expect(controller.state.locationAddress, contains('Đường DX 124'));
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
  ParticipantRiskReportDraft? lastDraft;

  @override
  Future<RiskReportSubmissionResult> submit(
    ParticipantRiskReportDraft draft, {
    RiskReportProgressCallback? onProgress,
  }) async {
    submitCalls += 1;
    lastDraft = draft;
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
