import 'package:delivery_app/features/risk_reports/widgets/risk_evidence_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'driver location shows a concrete address instead of coordinates',
    (tester) async {
      final descriptionController = TextEditingController();
      var captureCalls = 0;
      addTearDown(descriptionController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RiskEvidenceStep(
                descriptionController: descriptionController,
                photos: const [],
                latitude: 10.821,
                longitude: 106.721,
                locationAddress:
                    '123 Đường DX 124, Phường Tân An, Thành phố Hồ Chí Minh',
                locationRequired: true,
                messageCount: 0,
                descriptionError: null,
                photoError: null,
                locationError: null,
                onDescriptionChanged: (_) {},
                onPickPhotos: () {},
                onCaptureLocation: () => captureCalls += 1,
                onPickMessages: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('Đường DX 124'), findsOneWidget);
      expect(find.textContaining('10.82100'), findsNothing);
      expect(find.textContaining('106.72100'), findsNothing);
      await tester.tap(find.text('Gửi vị trí hiện tại'));
      await tester.pump();
      expect(captureCalls, 0);

      final locationAction = tester.widget<Semantics>(
        find.byKey(const ValueKey('risk-required-location-action')),
      );
      expect(locationAction.properties.enabled, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
