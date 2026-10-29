import 'package:giaohang_domain/giaohang_domain.dart';

String customerPaymentDate(DateTime value) {
  final local = VietnamTime.toWallClock(value);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} · ${two(local.hour)}:${two(local.minute)}';
}
