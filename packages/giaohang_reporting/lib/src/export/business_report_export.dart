import 'dart:typed_data';
import 'package:giaohang_domain/giaohang_domain.dart';
import '../business_report_strings.dart';
import '../utils/report_format.dart';
import 'xlsx_writer.dart';

enum BusinessReportFormat { excel, pdf }

/// The workbook stores untrusted names/codes as inline text, never formulas.
Uint8List businessReportExcel(BusinessReport report) {
  final rows = <List<Object>>[
    [BusinessReportStrings.statementTitle],
    [BusinessReportStrings.scope],
    [BusinessReportStrings.currentProfile, report.name],
    [BusinessReportStrings.profileHint],
    [report.address],
    [
      BusinessReportStrings.taxCode,
      report.taxCode ?? BusinessReportStrings.missing,
    ],
    [BusinessReportStrings.period, reportPeriod(report)],
    [BusinessReportStrings.generated, reportDate(report.generatedAt)],
    [BusinessReportStrings.currency],
    [BusinessReportStrings.deliveredCod, report.deliveredCod],
    [BusinessReportStrings.codCredits, report.walletCodCredits],
    [BusinessReportStrings.senderCharges, report.senderCharges],
    [BusinessReportStrings.recipientCharges, report.recipientCharges],
    [BusinessReportStrings.refunds, report.walletRefunds],
    [BusinessReportStrings.dateBasis],
    [BusinessReportStrings.costBasis],
    [BusinessReportStrings.codBasis],
  ];
  return writeReportWorkbook({
    'Tong quan': rows,
    'Giao nhan': [orderHeaders, ...report.orders.map(orderExportRow)],
    'Dong tien': [movementHeaders, ...report.movements.map(movementExportRow)],
  });
}

const orderHeaders = [
  BusinessReportStrings.code,
  BusinessReportStrings.date,
  BusinessReportStrings.status,
  BusinessReportStrings.cod,
  BusinessReportStrings.deliveryFee,
  BusinessReportStrings.platformFee,
  BusinessReportStrings.feePayer,
  BusinessReportStrings.returnFee,
  BusinessReportStrings.senderCharges,
  BusinessReportStrings.recipientCharges,
];

List<Object> orderExportRow(BusinessReportOrder o) => [
  o.code,
  reportDate(o.eventAt),
  BusinessReportStrings.orderStatus(o.status),
  o.cod,
  o.deliveryFee,
  o.platformFee,
  o.payer == 'sender'
      ? BusinessReportStrings.sender
      : o.payer == 'recipient'
      ? BusinessReportStrings.recipient
      : o.payer,
  o.settledReturnCharge,
  o.senderCharge,
  o.recipientCharge,
];

const movementHeaders = [
  BusinessReportStrings.reference,
  BusinessReportStrings.code,
  BusinessReportStrings.date,
  BusinessReportStrings.kind,
  BusinessReportStrings.amount,
  BusinessReportStrings.state,
];

List<Object> movementExportRow(BusinessReportMovement m) => [
  m.id,
  m.code ?? m.orderId ?? BusinessReportStrings.missing,
  reportDate(m.eventAt),
  BusinessReportStrings.movement(m.kind),
  m.amount,
  BusinessReportStrings.paymentState(m.paymentState),
];
