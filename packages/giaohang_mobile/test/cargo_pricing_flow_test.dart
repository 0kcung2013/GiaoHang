import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/core/models/order_submission_payload.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/widgets/cargo_pricing_fields.dart';
import 'helpers/utraffic_capture_fonts.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    if (Platform.environment['CARGO_PRICING_CAPTURE'] == '1') {
      await prepareUtrafficCaptureFonts();
    }
  });
  final settings = BusinessSettings(
    values: {...CargoPricingPolicy.defaults, 'cargo_pricing_enabled': 1},
  );

  test(
    'model copy and both payment payloads keep declaration and snapshot',
    () {
      final order = OrderModel.fromJson({
        'id': 'order',
        'item_weight_kg': 12,
        'cargo_details': {
          'size_group': 'large',
          'package_count': 2,
          'tier': 'extra_large',
          'surcharge': 30000,
        },
      });
      final restored = OrderModel.fromJson(
        order.copyWith(status: 'assigned').toJson(),
      );
      expect(restored.cargoDetails!.surcharge, 30000);
      expect(restored.cargoDetails!.packageCount, 2);
      expect(buildOrderSubmissionPayload(restored)['cargo_details'], {
        'size_group': 'large',
        'package_count': 2,
      });
      expect(
        buildOrderSubmissionPayload(
          OrderModel.fromJson({}),
        ).containsKey('cargo_details'),
        isFalse,
      );
    },
  );

  for (final width in [320.0, 390.0, 1000.0]) {
    testWidgets('size selection validates and renders at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final weight = TextEditingController(text: '12');
      final count = TextEditingController(text: '2');
      addTearDown(weight.dispose);
      addTearDown(count.dispose);
      final form = GlobalKey<FormState>();
      final boundaryKey = GlobalKey();
      var size = '';
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(width == 320 ? 1.6 : 1),
            ),
            child: RepaintBoundary(
              key: boundaryKey,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: form,
                      child: StatefulBuilder(
                        builder: (context, setState) => CargoPricingFields(
                          settings: settings,
                          weightController: weight,
                          countController: count,
                          sizeValue: size,
                          onSizeChanged: (value) =>
                              setState(() => size = value),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      await tester.ensureVisible(find.text('Tiêu chuẩn'));
      await tester.tap(find.text('Tiêu chuẩn'));
      await tester.pump();
      expect(form.currentState!.validate(), isTrue);
      expect(find.textContaining('30.000'), findsOneWidget);
      expect(find.textContaining('Rất lớn ·'), findsOneWidget);
      expect(find.textContaining('Áp dụng theo tổng cân nặng'), findsOneWidget);
      if (Platform.environment['CARGO_PRICING_CAPTURE'] == '1') {
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final rendered = await boundary.toImage();
          final bytes = await rendered.toByteData(
            format: ui.ImageByteFormat.png,
          );
          final file = File(
            '../../artifacts/cargo_pricing_20261031/customer-${width.toInt()}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          rendered.dispose();
        });
      }
      weight.text = '20.001';
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.textContaining('Tổng cân nặng tối đa'), findsOneWidget);
      weight.text = '0.0001';
      await tester.ensureVisible(find.text('Lớn'));
      await tester.tap(find.text('Lớn'));
      await tester.pump();
      await tester.ensureVisible(find.text(CargoPricingText.oversized));
      await tester.tap(find.text(CargoPricingText.oversized));
      await tester.pump();
      expect(form.currentState!.validate(), isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
