import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/support_orders/models/support_order.dart';

void main() {
  test('repairs remaining breve-A fragments from the reported history', () {
    final log = SupportOrderStatusLog.fromJson({
      'status': 'returning',
      'title': 'Tài xế đang hoĂ n hĂ ng',
      'description': 'TĂ i xế đĂ£ bắt đầu quay về điểm trả.',
    });
    expect(log.displayTitle, 'Tài xế đang hoàn hàng');
    expect(log.displayDescription, 'Tài xế đã bắt đầu quay về điểm trả.');
  });

  test('preserves valid Vietnamese breve-A alongside corrupt fragments', () {
    final log = SupportOrderStatusLog.fromJson({
      'title': 'Ă Ăn uống, hoàn hàng tại Đắk Lắk',
      'description': 'Chữ Ă và TĂ i xế',
    });
    expect(log.displayTitle, 'Ă Ăn uống, hoàn hàng tại Đắk Lắk');
    expect(log.displayDescription, 'Chữ Ă và Tài xế');
  });
  test('repairs mixed valid Vietnamese and Windows-1252 fragments', () {
    final log = SupportOrderStatusLog.fromJson({
      'status': 'returning',
      'title': 'Tài xáº¿ Ä‘ang hoÃ n hÃ ng',
      'description': 'Tài xáº¿ Ä‘Ã£ báº¯t Ä‘áº§u quay vá»\u0081 Ä‘iá»ƒm tráº£.',
    });
    expect(log.title, 'Tài xế đang hoàn hàng');
    expect(log.description, 'Tài xế đã bắt đầu quay về điểm trả.');
  });
  const title = 'Tài xế đang hoàn hàng';
  const description = 'Tài xế đã bắt đầu quay về điểm trả.';

  for (final depth in [0, 1, 2]) {
    test('return history decodes title and description at depth $depth', () {
      String encode(String text) {
        for (var i = 0; i < depth; i++) {
          text = latin1.decode(utf8.encode(text));
        }
        return text;
      }

      final log = SupportOrderStatusLog.fromJson({
        'status': 'returning',
        'title': encode(title),
        'description': encode(description),
        'created_at': '2026-10-17T14:43:00Z',
      });
      expect(log.title, title);
      expect(log.description, description);
      expect(log.status, 'returning');
    });
  }

  test('missing optional history text stays null', () {
    final log = SupportOrderStatusLog.fromJson({'status': 'returning'});
    expect(log.title, isNull);
    expect(log.description, isNull);
  });
}
