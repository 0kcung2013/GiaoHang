import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:delivery_app/core/models/order_status_log_model.dart';

void main() {
  test('repairs UTF-8 mojibake in order status log text', () {
    const expectedTitle = 'Đã có tài xế nhận đơn';
    const expectedDescription = 'Tài xế đã nhận đơn trong thời gian chờ.';

    final log = OrderStatusLogModel.fromJson({
      'id': 'log-1',
      'order_id': 'order-1',
      'status': 'assigned',
      'title': _asLatin1Mojibake(expectedTitle),
      'description': _asLatin1Mojibake(expectedDescription),
      'created_at': '2026-07-29T08:49:00Z',
    });

    expect(log.title, expectedTitle);
    expect(log.description, expectedDescription);
  });

  test('keeps valid Vietnamese status log text unchanged', () {
    const title = 'Đơn hàng đang được giao';
    const description = 'Tài xế đã lấy hàng và đang di chuyển.';

    final log = OrderStatusLogModel.fromJson({
      'id': 'log-2',
      'order_id': 'order-1',
      'status': 'delivering',
      'title': title,
      'description': description,
      'created_at': '2026-07-29T13:48:00Z',
    });

    expect(log.title, title);
    expect(log.description, description);
  });

  test('repairs repeated mojibake without over-decoding valid text', () {
    const expected = 'Chưa tìm thấy tài xế';
    final brokenOnce = _asLatin1Mojibake(expected);

    final log = OrderStatusLogModel.fromJson({
      'id': 'log-3',
      'order_id': 'order-1',
      'status': 'pending',
      'title': _asLatin1Mojibake(brokenOnce),
      'created_at': '2026-07-29T08:48:00Z',
    });

    expect(log.title, expected);
  });

  test('repairs lossy mojibake where non-breaking spaces became spaces', () {
    final log = OrderStatusLogModel.fromJson({
      'id': 'log-4',
      'order_id': 'order-1',
      'status': 'delivered',
      'title': 'Giao hÃ ng thÃ nh cÃ´ng',
      'description': 'TÃ i xáº¿ Ä‘Ã£ giao hÃ ng thÃ nh cÃ´ng.',
      'created_at': '2026-07-29T15:07:00Z',
    });

    expect(log.title, 'Giao hàng thành công');
    expect(log.description, 'Tài xế đã giao hàng thành công.');
  });
}

String _asLatin1Mojibake(String value) {
  return String.fromCharCodes(utf8.encode(value));
}
