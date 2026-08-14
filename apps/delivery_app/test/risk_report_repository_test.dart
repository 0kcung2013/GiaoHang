import 'dart:typed_data';

import 'package:delivery_app/features/risk_reports/data/risk_report_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  test('uploads to own report prefix and sends no severity', () async {
    final uploaded = <String>[];
    Map<String, dynamic>? rpcParams;
    final repository = SupabaseParticipantRiskReportRepository.test(
      currentUserId: () => 'user-1',
      createId: () => 'fixed-id',
      checkDuplicate: (_, _) async => false,
      processPhoto: (bytes) async => bytes,
      upload: (path, bytes) async => uploaded.add(path),
      remove: (_) async {},
      invokeCreate: (params) async {
        rpcParams = params;
        return {'report_id': 'fixed-id', 'status': 'open'};
      },
    );

    final result = await repository.submit(
      ParticipantRiskReportDraft(
        orderId: 'order-1',
        category: RiskCategory.safety,
        description: 'Khu vực giao hàng không an toàn.',
        photos: [
          RiskPhotoInput(
            fileName: 'evidence.png',
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
        ],
      ),
    );

    expect(result.reportId, 'fixed-id');
    expect(uploaded.single, 'user-1/fixed-id/fixed-id.jpg');
    expect(rpcParams, isNot(contains('severity')));
    expect(rpcParams?['p_photo_paths'], uploaded);
  });

  test('removes only uploaded paths when report creation fails', () async {
    final removed = <String>[];
    final repository = SupabaseParticipantRiskReportRepository.test(
      currentUserId: () => 'user-1',
      createId: () => 'fixed-id',
      checkDuplicate: (_, _) async => false,
      processPhoto: (bytes) async => bytes,
      upload: (_, _) async {},
      remove: (paths) async => removed.addAll(paths),
      invokeCreate: (_) => throw Exception('network'),
    );

    await expectLater(
      repository.submit(
        ParticipantRiskReportDraft(
          orderId: 'order-1',
          category: RiskCategory.other,
          description: 'Tôi cần bộ phận hỗ trợ kiểm tra đơn.',
          photos: [
            RiskPhotoInput(
              fileName: 'evidence.png',
              bytes: Uint8List.fromList([1]),
            ),
          ],
        ),
      ),
      throwsA(isA<RiskReportRepositoryException>()),
    );
    expect(removed, ['user-1/fixed-id/fixed-id.jpg']);
  });

  test('requires an authenticated user before uploading', () async {
    final repository = SupabaseParticipantRiskReportRepository.test(
      currentUserId: () => null,
      createId: () => 'fixed-id',
      checkDuplicate: (_, _) async => false,
      processPhoto: (bytes) async => bytes,
      upload: (_, _) async {},
      remove: (_) async {},
      invokeCreate: (_) async => <String, dynamic>{},
    );

    await expectLater(
      repository.submit(
        const ParticipantRiskReportDraft(
          orderId: 'order-1',
          category: RiskCategory.other,
          description: 'Tôi cần bộ phận hỗ trợ kiểm tra đơn.',
        ),
      ),
      throwsA(
        isA<RiskReportRepositoryException>().having(
          (error) => error.code,
          'code',
          RiskReportErrorCode.unauthorized,
        ),
      ),
    );
  });

  test('checks duplicate before processing or uploading photos', () async {
    var processed = 0;
    var uploaded = 0;
    var created = 0;
    final repository = SupabaseParticipantRiskReportRepository.test(
      currentUserId: () => 'user-1',
      createId: () => 'unused-id',
      checkDuplicate: (_, _) async => true,
      processPhoto: (bytes) async {
        processed += 1;
        return bytes;
      },
      upload: (_, _) async => uploaded += 1,
      remove: (_) async {},
      invokeCreate: (_) async {
        created += 1;
        return <String, dynamic>{};
      },
    );

    await expectLater(
      repository.submit(
        ParticipantRiskReportDraft(
          orderId: 'order-1',
          category: RiskCategory.safety,
          description: 'Khu vực giao hàng không an toàn.',
          photos: [
            RiskPhotoInput(
              fileName: 'evidence.jpg',
              bytes: Uint8List.fromList([1, 2, 3]),
            ),
          ],
        ),
      ),
      throwsA(
        isA<RiskReportRepositoryException>().having(
          (error) => error.code,
          'code',
          RiskReportErrorCode.duplicate,
        ),
      ),
    );
    expect(processed, 0);
    expect(uploaded, 0);
    expect(created, 0);
  });

  test('uploads photos with a concurrency limit and reports phases', () async {
    var id = 0;
    var activeUploads = 0;
    var maxActiveUploads = 0;
    final phases = <RiskReportSubmissionPhase>[];
    final repository = SupabaseParticipantRiskReportRepository.test(
      currentUserId: () => 'user-1',
      createId: () => 'id-${id++}',
      checkDuplicate: (_, _) async => false,
      processPhoto: (bytes) async => bytes,
      upload: (_, _) async {
        activeUploads += 1;
        if (activeUploads > maxActiveUploads) {
          maxActiveUploads = activeUploads;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
        activeUploads -= 1;
      },
      remove: (_) async {},
      invokeCreate: (_) async => {'report_id': 'report-1', 'status': 'open'},
    );

    await repository.submit(
      ParticipantRiskReportDraft(
        orderId: 'order-1',
        category: RiskCategory.other,
        description: 'Tôi cần bộ phận hỗ trợ kiểm tra đơn.',
        photos: List.generate(
          5,
          (index) => RiskPhotoInput(
            fileName: '$index.jpg',
            bytes: Uint8List.fromList([index]),
          ),
        ),
      ),
      onProgress: phases.add,
    );

    expect(maxActiveUploads, 2);
    expect(phases, RiskReportSubmissionPhase.values);
  });
}
