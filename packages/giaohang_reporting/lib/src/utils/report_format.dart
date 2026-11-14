import 'package:giaohang_domain/giaohang_domain.dart';

String reportDate(DateTime instant) {
  final d = VietnamTime.toWallClock(instant);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

String reportDay(DateTime wallClock) =>
    '${wallClock.day.toString().padLeft(2, '0')}/${wallClock.month.toString().padLeft(2, '0')}/${wallClock.year}';

String reportPeriod(BusinessReport report) =>
    '${reportDay(VietnamTime.toWallClock(report.start))} – ${reportDay(VietnamTime.toWallClock(report.end.subtract(const Duration(days: 1))))}';
