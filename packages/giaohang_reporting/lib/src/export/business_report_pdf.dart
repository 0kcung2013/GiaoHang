import 'package:flutter/services.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../business_report_strings.dart';
import '../utils/report_format.dart';
import 'business_report_export.dart';

Future<Uint8List> businessReportPdf(BusinessReport report) async {
  final fonts = await Future.wait([
    rootBundle.load(
      'packages/giaohang_reporting/assets/fonts/Roboto-Regular.ttf',
    ),
    rootBundle.load('packages/giaohang_reporting/assets/fonts/Roboto-Bold.ttf'),
  ]);
  final document = pw.Document(
    theme: pw.ThemeData.withFont(
      base: pw.Font.ttf(fonts[0]),
      bold: pw.Font.ttf(fonts[1]),
    ),
  );
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      maxPages: 700,
      header: (_) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Text(
          BusinessReportStrings.statementTitle,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      ),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            BusinessReportStrings.currency,
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.Text(
            '${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
      build: (_) => [
        pw.Text(
          BusinessReportStrings.scope,
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          report.name,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(report.address),
        pw.Text(
          '${BusinessReportStrings.taxCode}: ${report.taxCode ?? BusinessReportStrings.missing}',
        ),
        pw.Text(
          BusinessReportStrings.currentProfile,
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.Text(
          BusinessReportStrings.profileHint,
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          '${reportPeriod(report)} · ${BusinessReportStrings.generated}: ${reportDate(report.generatedAt)}',
        ),
        pw.SizedBox(height: 12),
        for (final metric in [
          (BusinessReportStrings.deliveredCod, report.deliveredCod),
          (BusinessReportStrings.codCredits, report.walletCodCredits),
          (BusinessReportStrings.senderCharges, report.senderCharges),
          (BusinessReportStrings.recipientCharges, report.recipientCharges),
          (BusinessReportStrings.refunds, report.walletRefunds),
        ])
          pw.Text(
            '${metric.$1}: ${metric.$2} VND',
            style: const pw.TextStyle(fontSize: 10),
          ),
        pw.SizedBox(height: 10),
        pw.Text(
          BusinessReportStrings.dateBasis,
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.Text(
          BusinessReportStrings.codBasis,
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.Text(
          BusinessReportStrings.costBasis,
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          BusinessReportStrings.orders,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (report.orders.isEmpty)
          pw.Text(BusinessReportStrings.empty)
        else
          _table(orderHeaders, report.orders.map(orderExportRow).toList()),
        pw.SizedBox(height: 16),
        pw.Text(
          BusinessReportStrings.movements,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (report.movements.isEmpty)
          pw.Text(BusinessReportStrings.empty)
        else
          _table(
            movementHeaders,
            report.movements.map(movementExportRow).toList(),
          ),
      ],
    ),
  );
  return document.save();
}

pw.Widget _table(
  List<String> headers,
  List<List<Object>> rows,
) => pw.TableHelper.fromTextArray(
  headers: headers,
  data: rows.map((r) => r.map((v) => v.toString()).toList()).toList(),
  headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0F1B2D)),
  headerStyle: pw.TextStyle(
    color: PdfColors.white,
    fontWeight: pw.FontWeight.bold,
    fontSize: 8,
  ),
  cellStyle: const pw.TextStyle(fontSize: 8),
  cellPadding: const pw.EdgeInsets.all(5),
  oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F6F8)),
  border: null,
);
