import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:operations_web/features/support/constants/support_risk_conversion_strings.dart';
import 'package:operations_web/features/support/dialogs/support_ticket_operation_dialogs.dart';

const _submitKey = Key('confirm-support-risk-conversion');

Future<void> _open(
  WidgetTester tester, {
  bool needsComponent = true,
  String title = 'Trao đổi với CSKH',
  String description = 'Không thể đăng nhập vào ứng dụng.',
  double scale = 1,
  ValueChanged<SupportRiskConversionDraft?>? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showSupportRiskConversionDialog(
                context,
                initialTitle: title,
                initialDescription: description,
                needsComponent: needsComponent,
              );
              onResult?.call(result);
            },
            child: const Text('Mở form'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Mở form'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'preserves prefill, validates required input and returns trimmed draft',
    (tester) async {
      SupportRiskConversionDraft? result;
      await _open(
        tester,
        description: '22222222',
        onResult: (value) => result = value,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('support-risk-title')))
            .controller!
            .text,
        'Trao đổi với CSKH',
      );
      expect(
        find.text(SupportRiskConversionStrings.componentError),
        findsNothing,
      );
      await tester.tap(find.byKey(_submitKey));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(
        find.text(SupportRiskConversionStrings.componentError),
        findsOneWidget,
      );
      expect(
        find.text(SupportRiskConversionStrings.descriptionError),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('support-risk-title')),
        ' a ',
      );
      await tester.tap(find.byKey(_submitKey));
      await tester.pumpAndSettle();
      expect(
        find.text(SupportRiskConversionStrings.titleError),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('support-risk-title')),
        '  Lỗi đăng nhập  ',
      );
      await tester.enterText(
        find.byKey(const Key('support-risk-description')),
        '  Không thể đăng nhập vào ứng dụng.  ',
      );
      await tester.enterText(
        find.byKey(const Key('support-risk-component')),
        '  Đăng nhập  ',
      );
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<RiskCategory>),
      );
      await tester.tap(find.byType(DropdownButtonFormField<RiskCategory>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hệ thống').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<RiskSeverity>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cao').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_submitKey));
      await tester.pumpAndSettle();
      expect(result?.title, 'Lỗi đăng nhập');
      expect(result?.description, 'Không thể đăng nhập vào ứng dụng.');
      expect(result?.component, 'Đăng nhập');
      expect(result?.category, RiskCategory.system);
      expect(result?.severity, RiskSeverity.high);
    },
  );

  testWidgets(
    'order report omits component and preserves classification defaults',
    (tester) async {
      SupportRiskConversionDraft? result;
      await _open(
        tester,
        needsComponent: false,
        onResult: (value) => result = value,
      );
      expect(find.byKey(const Key('support-risk-component')), findsNothing);
      await tester.tap(find.byKey(_submitKey));
      await tester.pumpAndSettle();
      expect(result?.component, isNull);
      expect(result?.category, RiskCategory.other);
      expect(result?.severity, RiskSeverity.medium);
    },
  );

  testWidgets('cancel and back dismiss without producing a draft', (
    tester,
  ) async {
    final results = <SupportRiskConversionDraft?>[];
    await _open(tester, onResult: results.add);
    await tester.tap(find.text(SupportRiskConversionStrings.cancel));
    await tester.pumpAndSettle();
    expect(results, [null]);
    await tester.tap(find.text('Mở form'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(results, [null, null]);
  });

  for (final viewport in [
    (size: const Size(320, 568), scale: 1.0, keyboard: 180.0),
    (size: const Size(375, 568), scale: 1.6, keyboard: 180.0),
    (size: const Size(1280, 800), scale: 1.0, keyboard: 0.0),
  ]) {
    testWidgets('actions and fields remain usable at $viewport', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = viewport.size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      await _open(tester, scale: viewport.scale);
      expect(find.byKey(_submitKey).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('support-risk-title')));
      tester.view.viewInsets = FakeViewPadding(bottom: viewport.keyboard);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('support-risk-title')),
        'Tiêu đề mới',
      );
      expect(find.byKey(_submitKey).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<RiskSeverity>),
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(DropdownButtonFormField<RiskSeverity>).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
