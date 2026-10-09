/// Các tiêu đề hệ thống cũ đã bị đọc UTF-8 bằng Windows-1258 trên server.
/// Chỉ khôi phục chuỗi đã biết; giữ nguyên tiêu đề tùy chỉnh và nội dung báo cáo.
String restoreLegacyRiskTitle(String title) => _legacyTitles[title] ?? title;

const _legacyTitles = {
  'Giao hĂ ng cháº­m': 'Giao hàng chậm',
  'Ä\u0090á»‹a chá»‰ báº¥t thÆ°á»\u009dng': 'Địa chỉ bất thường',
  'KhĂ´ng liĂªn láº¡c Ä‘Æ°á»£c': 'Không liên lạc được',
  'HĂ ng hĂ³a báº¥t thÆ°á»\u009dng': 'Hàng hóa bất thường',
  'Váº¥n Ä‘á»\u0081 thanh toĂ¡n': 'Vấn đề thanh toán',
  'Váº¥n Ä‘á»\u0081 an toĂ n': 'Vấn đề an toàn',
  'Sá»± cá»‘ khĂ¡c': 'Sự cố khác',
};
