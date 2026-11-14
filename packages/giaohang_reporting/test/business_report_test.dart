import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:giaohang_reporting/giaohang_reporting.dart';
import 'package:giaohang_reporting/src/export/business_report_export.dart';
import 'package:giaohang_reporting/src/export/business_report_pdf.dart';
import 'package:xml/xml.dart';
import 'package:giaohang_reporting/src/widgets/report_export_sheet.dart';
import 'report_fixture.dart';

class _Repository implements BusinessReportRepository {
  final requests = <Completer<BusinessReport>>[];
  @override
  Future<BusinessReport> fetch(
    String customerId,
    DateTime start,
    DateTime end,
  ) {
    final response = Completer<BusinessReport>();
    requests.add(response);
    return response.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadReportTestFonts);
  test(
    'completion costs separate payers, return fees, refunds and compensation',
    () {
      final report = reportFixture();
      expect(report.deliveredCod, 300000);
      expect(report.walletCodCredits, 300000); // risk_credit is not COD revenue
      expect(report.walletRefunds, 600);
      expect(
        report.senderCharges,
        30000,
      ); // returned: D + return, platform fee waived
      expect(report.recipientCharges, 20600);
      expect(report.orders.last.senderCharge, 0); // cancelled
      expect(BusinessReport.fromJson(report.toJson()).senderCharges, 30000);
      expect(
        businessReportBoundary(DateTime(2026, 11, 1)),
        DateTime.utc(2026, 10, 31, 17),
      );
    },
  );

  test(
    'xlsx is a valid ZIP/XML workbook, preserves numbers and treats input as text',
    () {
      final json = reportFixture().toJson();
      (json['profile'] as Map)['business_name'] = '=1+1 & <shop>\u0001';
      final bytes = businessReportExcel(BusinessReport.fromJson(json));
      final zip = ZipDecoder().decodeBytes(bytes, verify: true);
      final texts = {
        for (final file in zip.files) file.name: utf8.decode(file.content),
      };
      for (final text in texts.values) {
        expect(() => XmlDocument.parse(text), returnsNormally);
      }
      final sheet = XmlDocument.parse(texts['xl/worksheets/sheet1.xml']!);
      expect(sheet.findAllElements('f'), isEmpty);
      expect(
        sheet.findAllElements('t').map((n) => n.innerText),
        contains('=1+1 & <shop>'),
      );
      expect(
        sheet.findAllElements('v').map((n) => n.innerText),
        contains('30000'),
      );
      expect(texts.keys.where((n) => n.startsWith('xl/worksheets/')).length, 3);
    },
  );

  test(
    'PDF exports multipage Vietnamese data with bundled offline fonts',
    () async {
      final report = reportFixture(orderCount: 90);
      final bytes = await businessReportPdf(report);
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(10000));
      final capture = Platform.environment['GIAOHANG_REPORT_CAPTURE'];
      if (capture != null) {
        Directory(capture).createSync(recursive: true);
        File('$capture/report.pdf').writeAsBytesSync(bytes);
        File(
          '$capture/report.xlsx',
        ).writeAsBytesSync(businessReportExcel(report));
      }
    },
  );

  for (final viewport in [
    (const Size(320, 568), 1.6),
    (const Size(390, 844), 1.0),
    (const Size(390, 844), 1.6),
    (const Size(1100, 800), 1.0),
    (const Size(1100, 800), 1.6),
  ]) {
    final size = viewport.$1;
    final scale = viewport.$2;
    testWidgets('compact report and download sheet render $size at $scale', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Repository();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            fontFamily: AppTextStyles.bodyMedium.fontFamily,
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(key: boundary, child: child!),
          ),
          home: BusinessReportScreen(
            customerId: 'customer-1',
            repository: repository,
          ),
        ),
      );
      await tester.pump();
      expect(find.text(BusinessReportStrings.export), findsNothing);
      repository.requests.single.complete(reportFixture());
      await tester.pumpAndSettle();
      expect(find.text('Cửa hàng An & Bình'), findsNothing);
      expect(find.text(BusinessReportStrings.serviceExpense), findsOneWidget);
      expect(find.text('Chứng từ'), findsNothing);
      expect(tester.takeException(), isNull);
      await _capture(tester, boundary, 'report-${size.width.toInt()}-$scale');
      final download = find.byWidgetPredicate(
        (widget) => widget is FilledButton,
      );
      await tester.ensureVisible(download);
      await tester.tap(download);
      await tester.pumpAndSettle();
      expect(find.text(BusinessReportStrings.excelHint), findsOneWidget);
      expect(find.text(BusinessReportStrings.pdfHint), findsOneWidget);
      expect(find.text(BusinessReportStrings.exportScope), findsOneWidget);
      await _capture(tester, boundary, 'download-${size.width.toInt()}-$scale');
      await tester.ensureVisible(
        find.text(BusinessReportStrings.statementProfile),
      );
      await tester.tap(find.text(BusinessReportStrings.statementProfile));
      await tester.pumpAndSettle();
      expect(find.text('Cửa hàng An & Bình'), findsOneWidget);
      expect(find.text('0012345678'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip(BusinessReportStrings.close));
      await tester.tap(find.byTooltip(BusinessReportStrings.close));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text(BusinessReportStrings.movements));
      await tester.tap(find.text(BusinessReportStrings.movements));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text(BusinessReportStrings.movement('delivery_credit')),
      );
      await tester.tap(
        find.text(BusinessReportStrings.movement('delivery_credit')),
      );
      await tester.pumpAndSettle();
      expect(find.text('wallet:cod'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.byTooltip(BusinessReportStrings.previousMonth).hitTestable(),
        -400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(BusinessReportStrings.previousMonth));
      await tester.pump();
      // Previous data cannot be exported while another period is loading or failed.
      expect(find.text(BusinessReportStrings.export), findsNothing);
      repository.requests.last.completeError(Exception('offline'));
      await tester.pumpAndSettle();
      expect(find.text(BusinessReportStrings.error), findsOneWidget);
      expect(find.text(BusinessReportStrings.export), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('download choices return the chosen file format', (tester) async {
    BusinessReportFormat? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => selected = await showReportExportSheet(
                context,
                reportFixture(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    for (final option in [
      (BusinessReportStrings.excel, BusinessReportFormat.excel),
      (BusinessReportStrings.pdf, BusinessReportFormat.pdf),
    ]) {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option.$1));
      await tester.pumpAndSettle();
      expect(selected, option.$2);
    }
  });

  testWidgets(
    'staff view identifies sender costs and empty period can be downloaded',
    (tester) async {
      final repository = _Repository();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BusinessReportPanel(
              customerId: 'customer-1',
              repository: repository,
              staffView: true,
              today: DateTime(2026, 11, 7),
            ),
          ),
        ),
      );
      final json = reportFixture().toJson();
      json['orders'] = [];
      json['movements'] = [];
      repository.requests.single.complete(BusinessReport.fromJson(json));
      await tester.pumpAndSettle();
      expect(
        find.text(BusinessReportStrings.staffServiceExpense),
        findsOneWidget,
      );
      expect(find.text(BusinessReportStrings.empty), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byWidgetPredicate((widget) => widget is FilledButton),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reading guidance explains evidence scope without a tax submission action',
    (tester) async {
      final repository = _Repository();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BusinessReportPanel(
              customerId: 'customer-1',
              repository: repository,
              today: DateTime(2026, 11, 7),
            ),
          ),
        ),
      );
      repository.requests.single.complete(reportFixture());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip(BusinessReportStrings.guide));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(BusinessReportStrings.guide));
      await tester.pumpAndSettle();
      expect(find.text(BusinessReportStrings.codBasis), findsOneWidget);
      expect(find.text(BusinessReportStrings.dateBasis), findsOneWidget);
      expect(find.textContaining('Nộp thuế'), findsNothing);
      await tester.ensureVisible(find.text(BusinessReportStrings.close));
      await tester.pumpAndSettle();
      await tester.tap(find.text(BusinessReportStrings.close));
      await tester.pumpAndSettle();
      expect(find.text(BusinessReportStrings.dateBasis), findsNothing);
    },
  );

  testWidgets('late responses cannot replace a newer period', (tester) async {
    final repository = _Repository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BusinessReportPanel(
            customerId: 'customer-1',
            repository: repository,
            today: DateTime(2026, 11, 7),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip(BusinessReportStrings.previousMonth));
    await tester.pump();
    repository.requests[1].completeError(Exception('newer request failed'));
    await tester.pumpAndSettle();
    repository.requests[0].complete(reportFixture());
    await tester.pumpAndSettle();
    expect(find.text(BusinessReportStrings.error), findsOneWidget);
    expect(find.text('Cửa hàng An & Bình'), findsNothing);
  });
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
) async {
  final directory = Platform.environment['GIAOHANG_REPORT_CAPTURE'];
  if (directory == null) return;
  await tester.runAsync(() async {
    Directory(directory).createSync(recursive: true);
    final snapshot =
        await (boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage();
    final data = await snapshot.toByteData(format: ui.ImageByteFormat.png);
    await File('$directory/$name.png').writeAsBytes(data!.buffer.asUint8List());
    snapshot.dispose();
  });
}
