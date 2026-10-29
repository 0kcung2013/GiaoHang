import 'package:giaohang_domain/giaohang_domain.dart' show formatVndDigits;

class SettingsField {
  const SettingsField(
    this.key,
    this.label, {
    this.unit = '',
    this.min,
    this.max,
    this.divisor = 1,
    this.description,
  });
  final String key, label, unit;
  final int? min, max;
  final int divisor;
  final String? description;
  bool get numeric => min != null;
  bool get monetary => unit == 'đ' || unit == 'đ/km';

  String display(Object value) => monetary
      ? formatVndDigits(value as num)
      : numeric
      ? ((value as num) / divisor).toString().replaceFirst(RegExp(r'\.0$'), '')
      : value.toString();

  Object? parse(String value) {
    if (!numeric) return value.trim();
    if (monetary) {
      final text = value.trim();
      if (!RegExp(r'^-?(?:\d+|\d{1,3}(?:\.\d{3})+)$').hasMatch(text)) {
        return null;
      }
      return int.tryParse(text.replaceAll('.', ''));
    }
    final parsed = num.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null || !parsed.isFinite) return null;
    final scaled = parsed * divisor;
    if ((scaled - scaled.round()).abs() > 0.000001) return null;
    return scaled.round();
  }

  String? validate(String value) {
    final parsed = parse(value);
    if (numeric) {
      if (parsed is! int || parsed < min! || parsed > max!) {
        return 'Nhập từ ${display(min!)} đến ${display(max!)} $unit.';
      }
    } else if (key == 'company_name' &&
        (value.trim().isEmpty || value.trim().length > 80)) {
      return 'Nhập tên đơn vị từ 1 đến 80 ký tự.';
    } else if (key == 'support_email' &&
        (value.length > 254 ||
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim()))) {
      return 'Nhập email hợp lệ.';
    } else if (key == 'support_phone' &&
        !RegExp(r'^[+0-9() .-]{0,25}$').hasMatch(value.trim())) {
      return 'Nhập số điện thoại hợp lệ, tối đa 25 ký tự.';
    }
    return null;
  }
}

class SettingsGroup {
  const SettingsGroup(this.label, this.hint, this.fields);
  final String label, hint;
  final List<SettingsField> fields;
}

const settingsGroups = [
  SettingsGroup(
    'Giá cước & hoàn hàng',
    'Phí cơ bản + giá mỗi km vượt phần đã bao gồm. Áp dụng cho đơn mới.',
    [
      SettingsField(
        'base_fee',
        'Phí cơ bản',
        unit: 'đ',
        min: 5000,
        max: 1000000,
        description:
            'Khoản cố định cho mỗi đơn, đã gồm số km được cấu hình bên dưới.',
      ),
      SettingsField(
        'included_distance_m',
        'Khoảng cách trong phí cơ bản',
        unit: 'km',
        min: 0,
        max: 100000,
        divisor: 1000,
        description: 'Trong quãng đường này chỉ tính phí cơ bản.',
      ),
      SettingsField(
        'standard_per_km',
        'Giá mỗi km vượt phần đã bao gồm',
        unit: 'đ/km',
        min: 0,
        max: 100000,
        description:
            'Một đơn giá áp dụng cho toàn bộ phần quãng đường vượt gói.',
      ),
      SettingsField(
        'rounding_unit',
        'Làm tròn lên theo',
        unit: 'đ',
        min: 1,
        max: 10000,
        description: 'Làm tròn lên tổng phí sau khi cộng các khoản.',
      ),
      SettingsField(
        'return_fee_rate_bps',
        'Tỷ lệ phí hoàn',
        unit: '%',
        min: 0,
        max: 10000,
        divisor: 100,
        description:
            'Tính trên cước giao đã chốt của đơn; đơn vị vận hành chi trả.',
      ),
    ],
  ),
  SettingsGroup(
    'Hàng hóa & COD',
    'Giới hạn trong phạm vi thanh toán hiện được hệ thống hỗ trợ.',
    [
      SettingsField(
        'max_cod',
        'Thu hộ COD tối đa',
        unit: 'đ',
        min: 0,
        max: 10000000,
      ),
      SettingsField(
        'max_goods_value',
        'Giá trị hàng tối đa',
        unit: 'đ',
        min: 1,
        max: 100000000,
      ),
      SettingsField(
        'max_paid_goods_value',
        'Giá trị hàng đã thanh toán tối đa',
        unit: 'đ',
        min: 1,
        max: 2000000,
      ),
    ],
  ),
  SettingsGroup(
    'Nạp ví tài xế',
    'Áp dụng cho lần tạo giao dịch mới; giữ nguyên giao dịch đang chờ.',
    [
      SettingsField(
        'topup_min',
        'Nạp tối thiểu mỗi lần',
        unit: 'đ',
        min: 5000,
        max: 10000000,
      ),
      SettingsField(
        'topup_max',
        'Nạp tối đa mỗi lần',
        unit: 'đ',
        min: 5000,
        max: 10000000,
      ),
    ],
  ),
  SettingsGroup(
    'Phân công đơn',
    'Chốt theo đơn mới. Đơn cũ giữ thời gian và phạm vi đã chốt.',
    [
      SettingsField(
        'offer_seconds',
        'Thời gian phản hồi lời mời',
        unit: 'giây',
        min: 15,
        max: 300,
      ),
      SettingsField(
        'assignment_minutes',
        'Thời gian tìm tài xế',
        unit: 'phút',
        min: 1,
        max: 60,
      ),
      SettingsField(
        'auto_radius_m',
        'Phạm vi tự động phân công',
        unit: 'km',
        min: 100,
        max: 10000,
        divisor: 1000,
      ),
      SettingsField(
        'free_pick_radius_m',
        'Phạm vi tài xế tự chọn đơn',
        unit: 'km',
        min: 101,
        max: 20000,
        divisor: 1000,
      ),
    ],
  ),
  SettingsGroup(
    'Thông tin đơn vị',
    'Thông tin hiển thị trong ứng dụng và liên hệ hỗ trợ.',
    [
      SettingsField('company_name', 'Tên đơn vị'),
      SettingsField('support_phone', 'Điện thoại hỗ trợ'),
      SettingsField('support_email', 'Email hỗ trợ'),
    ],
  ),
  SettingsGroup(
    'Phí sàn',
    'Tính trên cước giao, không tính COD. Chỉ áp dụng cho đơn mới.',
    [
      SettingsField(
        'customer_individual_fee_bps',
        'Khách cá nhân',
        unit: '%',
        min: 0,
        max: 10000,
        divisor: 100,
      ),
      SettingsField(
        'customer_business_fee_bps',
        'Khách doanh nghiệp',
        unit: '%',
        min: 0,
        max: 10000,
        divisor: 100,
      ),
      SettingsField(
        'driver_platform_fee_bps',
        'Tài xế',
        unit: '%',
        min: 0,
        max: 10000,
        divisor: 100,
      ),
    ],
  ),
];

Iterable<SettingsField> get settingsFields =>
    settingsGroups.expand((g) => g.fields);

const pricingFieldKeys = {
  'base_fee',
  'included_distance_m',
  'standard_per_km',
  'rounding_unit',
};

String? validateSettingsRelations(Map<String, dynamic> values) {
  int n(String key) => values[key] as int;
  if (n('auto_radius_m') >= n('free_pick_radius_m')) {
    return 'Phạm vi tự chọn phải lớn hơn phạm vi tự động phân công.';
  }
  if (n('topup_min') > n('topup_max')) {
    return 'Mức nạp tối đa phải lớn hơn hoặc bằng mức nạp tối thiểu.';
  }
  if (n('max_paid_goods_value') > n('max_goods_value')) {
    return 'Giới hạn hàng đã thanh toán không được vượt giá trị hàng tối đa.';
  }
  if (n('offer_seconds') > n('assignment_minutes') * 60) {
    return 'Thời gian lời mời không được vượt thời gian tìm tài xế.';
  }
  return null;
}
