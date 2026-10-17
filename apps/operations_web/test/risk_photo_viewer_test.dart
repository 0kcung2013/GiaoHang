import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:operations_web/features/risk_reports/data/risk_report_repository.dart';
import 'package:operations_web/features/risk_reports/widgets/risk_attachment_section.dart';
import 'package:operations_web/features/risk_reports/dialogs/risk_photo_viewer.dart';

void main() {
  for (final size in [const Size(375, 600), const Size(1280, 800)]) {
    testWidgets('evidence opens gallery, changes photo and closes at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime(2026);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RiskAttachmentSection(
                items: [
                  for (final i in [1, 2])
                    RiskReportAttachmentView(
                      attachment: RiskReportAttachment(
                        id: '$i',
                        riskReportId: 'risk',
                        orderId: 'order',
                        evidenceType: RiskEvidenceType.photo,
                        storagePath: 'photo-$i',
                        latitude: null,
                        longitude: null,
                        capturedAt: now,
                        createdAt: now,
                      ),
                      signedUrl: 'https://example.test/$i.png',
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(find.byType(RiskPhotoViewer), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('Ảnh bằng chứng · 1/2'), findsOneWidget);
      await tester.tap(find.byTooltip('Ảnh tiếp theo'));
      await tester.pumpAndSettle();
      expect(find.text('Ảnh bằng chứng · 2/2'), findsOneWidget);
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();
      expect(find.byType(RiskPhotoViewer), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
