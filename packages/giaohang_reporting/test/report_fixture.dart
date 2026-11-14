import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:google_fonts/google_fonts.dart';

BusinessReport reportFixture({int orderCount = 3}) => BusinessReport.fromJson({
  'profile': {
    'id': 'customer-1',
    'business_name': 'Cửa hàng An & Bình',
    'business_address': '123 Nguyễn Trãi, TP. Hồ Chí Minh',
    'business_tax_code': '0012345678',
  },
  'start': '2026-10-31T17:00:00Z',
  'end': '2026-11-30T17:00:00Z',
  'generated_at': '2026-11-07T04:20:00Z',
  'orders': [
    for (var i = 0; i < orderCount; i++)
      {
        'id': 'order-$i',
        'tracking_code': 'GH${i.toString().padLeft(5, '0')}',
        'status': i % 3 == 0
            ? 'delivered'
            : i % 3 == 1
            ? 'returned'
            : 'cancelled',
        'event_at': '2026-11-06T17:05:00Z',
        'cod_collection_amount': 300000,
        'delivery_fee': 20000,
        'customer_platform_fee_amount': 600,
        'delivery_fee_payer': i % 3 == 0 ? 'recipient' : 'sender',
        'payment_status': 'paid',
        'return_charge': 10000,
        'return_fee_status': 'settled',
      },
  ],
  'movements': [
    {
      'id': 'wallet:cod',
      'kind': 'delivery_credit',
      'amount': 300000,
      'event_at': '2026-11-05T04:00:00Z',
      'tracking_code': 'GH00000',
      'payment_state': null,
    },
    {
      'id': 'wallet:refund',
      'kind': 'delivery_fee_refund',
      'amount': 600,
      'event_at': '2026-11-06T04:00:00Z',
      'tracking_code': 'GH00001',
      'payment_state': null,
    },
    {
      'id': 'wallet:compensation',
      'kind': 'risk_credit',
      'amount': 120000,
      'event_at': '2026-11-06T05:00:00Z',
      'tracking_code': 'GH00002',
      'payment_state': null,
    },
  ],
});

Future<void> loadReportTestFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  final bytes = File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync();
  const names = ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        if (key == 'AssetManifest.bin')
          return const StandardMessageCodec().encodeMessage({
            'JetBrainsMono-Medium.ttf': [
              {'asset': 'JetBrainsMono-Medium.ttf'},
            ],
            for (final name in names)
              'PlusJakartaSans-$name.ttf': [
                {'asset': 'PlusJakartaSans-$name.ttf'},
              ],
          });
        if (key.startsWith('packages/giaohang_reporting/assets/fonts/'))
          return ByteData.sublistView(
            File(
              key.replaceFirst('packages/giaohang_reporting/', ''),
            ).readAsBytesSync(),
          );
        if (key.endsWith('.ttf')) return ByteData.sublistView(bytes);
        return null;
      });
  for (final weight in [
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
    FontWeight.w800,
  ]) {
    GoogleFonts.plusJakartaSans(fontWeight: weight);
  }
  GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w500);
  await GoogleFonts.pendingFonts();
  final loader = FontLoader(AppTextStyles.bodyMedium.fontFamily!)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
  final icons = File.fromUri(
    File(
      Platform.resolvedExecutable,
    ).parent.uri.resolve('../../material_fonts/materialicons-regular.otf'),
  );
  await (FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
      .load();
}
