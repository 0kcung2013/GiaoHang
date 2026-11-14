import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:share_plus/share_plus.dart';
import 'business_report_export.dart';
import 'business_report_pdf.dart';
import '../business_report_strings.dart';
import '../utils/report_format.dart';

Future<void> shareBusinessReport(
  BusinessReport report,
  BusinessReportFormat format,
  Rect origin,
) async {
  final Uint8List bytes = format == BusinessReportFormat.excel
      ? businessReportExcel(report)
      : await businessReportPdf(report);
  final extension = format == BusinessReportFormat.excel ? 'xlsx' : 'pdf';
  final calendarStart = reportDay(
    VietnamTime.toWallClock(report.start),
  ).replaceAll('/', '-');
  final filename = 'giaohang_${report.customerId}_$calendarStart.$extension';
  await SharePlus.instance.share(
    ShareParams(
      title: BusinessReportStrings.title,
      files: [
        XFile.fromData(
          bytes,
          mimeType: format == BusinessReportFormat.excel
              ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
              : 'application/pdf',
          name: filename,
        ),
      ],
      fileNameOverrides: [filename],
      sharePositionOrigin: origin,
    ),
  );
}
