import 'package:test/test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

RiskReport readTitle(String title) => RiskReport.fromJson({
  'id': 'risk',
  'category': 'contact_issue',
  'title': title,
  'created_at': '2026-10-08T01:26:07Z',
  'updated_at': '2026-10-08T01:26:07Z',
});

void main() {
  test('restores all seven legacy participant report titles', () {
    const titles = {
      'Giao hĂ ng cháº­m': 'Giao hàng chậm',
      'Ä\u0090á»‹a chá»‰ báº¥t thÆ°á»\u009dng': 'Địa chỉ bất thường',
      'KhĂ´ng liĂªn láº¡c Ä‘Æ°á»£c': 'Không liên lạc được',
      'HĂ ng hĂ³a báº¥t thÆ°á»\u009dng': 'Hàng hóa bất thường',
      'Váº¥n Ä‘á»\u0081 thanh toĂ¡n': 'Vấn đề thanh toán',
      'Váº¥n Ä‘á»\u0081 an toĂ n': 'Vấn đề an toàn',
      'Sá»± cá»‘ khĂ¡c': 'Sự cố khác',
    };
    for (final entry in titles.entries) {
      expect(readTitle(entry.key).title, entry.value);
      expect(readTitle(entry.value).title, entry.value);
    }
  });

  test(
    'reads the legacy server title in Vietnamese without changing custom titles',
    () {
      expect(
        readTitle('KhĂ´ng liĂªn láº¡c Ä‘Æ°á»£c').title,
        'Không liên lạc được',
      );
      for (final title in [
        'Không liên lạc được',
        'Không liên lạc được sau 3 cuộc gọi',
        'Custom title',
      ]) {
        expect(readTitle(title).title, title);
      }
    },
  );
}
