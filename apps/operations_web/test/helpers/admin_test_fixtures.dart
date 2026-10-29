import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:operations_web/features/admin/data/admin_repository.dart';
import 'package:operations_web/features/admin/data/admin_order_repository.dart';
import 'package:operations_web/features/admin/models/admin_snapshot.dart';
import 'package:operations_web/features/support_orders/models/support_order.dart';

Future<void> loadAdminTestFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  final bytes = File.fromUri(
    File(
      Platform.resolvedExecutable,
    ).parent.uri.resolve('../../material_fonts/roboto-regular.ttf'),
  ).readAsBytesSync();
  const names = ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        if (key == 'AssetManifest.bin') {
          return const StandardMessageCodec().encodeMessage({
            'JetBrainsMono-Medium.ttf': [
              {'asset': 'JetBrainsMono-Medium.ttf'},
            ],
            for (final name in names)
              'PlusJakartaSans-$name.ttf': [
                {'asset': 'PlusJakartaSans-$name.ttf'},
              ],
          });
        }
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
}

SupportOrder adminOrderFixture([int n = 1]) => SupportOrder(
  id: 'order-$n',
  trackingCode: 'GH-102$n',
  status: n.isEven ? 'delivering' : 'pending',
  pickupAddress: '12 Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh',
  deliveryAddress: '50 Phan Xích Long, Phú Nhuận',
  createdAt: DateTime.utc(2026, 10, 20, 3),
  updatedAt: DateTime.utc(2026, 10, 20, 4),
  totalPrice: 42000,
  deliveryFee: 42000,
);

class FakeAdminRepository implements AdminRepository {
  AdminSnapshot snapshot = AdminSnapshot(
    values: {for (final m in AdminMetric.values) m: m.index + 1},
    updatedAt: DateTime.utc(2026, 10, 20, 4),
  );
  bool fail = false;
  int snapshotReads = 0;
  int accountReads = 0;
  String? role;
  @override
  Future<AdminSnapshot> fetchSnapshot() async {
    snapshotReads++;
    if (fail) throw Exception('offline');
    return snapshot;
  }

  @override
  Future<List<AdminAccount>> fetchAccounts({
    String query = '',
    String? role,
    int offset = 0,
  }) async {
    accountReads++;
    this.role = role;
    if (fail) throw Exception('offline');
    return [
      AdminAccount(
        id: 'customer-1',
        name: 'Nguyễn Minh An',
        role: role ?? 'customer',
        email: 'an@example.invalid',
        phone: '0900000000',
      ),
    ];
  }
}

typedef AdminPageHandler =
    Future<List<SupportOrder>> Function(
      String query,
      String? status,
      int offset,
    );

class FakeAdminOrders implements AdminOrderRepository {
  int reads = 0, details = 0;
  bool fail = false;
  AdminPageHandler? handler;
  List<SupportOrder> rows = [adminOrderFixture(1), adminOrderFixture(2)];
  @override
  Future<List<SupportOrder>> fetchPage({
    String query = '',
    String? status,
    int offset = 0,
  }) async {
    reads++;
    if (handler != null) return handler!(query, status, offset);
    if (fail) throw Exception('offline');
    return rows;
  }

  @override
  Future<SupportOrder> fetchOrder(String id) async {
    details++;
    return rows.firstWhere((o) => o.id == id);
  }
}

Widget adminTestApp(Widget child, {double scale = 1}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: child),
);
