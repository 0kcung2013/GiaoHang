/// Cấu hình nghiệp vụ dùng chung; backend kiểm tra và chốt phiên bản chính thức.
class BusinessSettings {
  BusinessSettings({this.revision = 0, Map<String, dynamic>? values})
    : values = Map.unmodifiable({...defaults, ...?values});

  final int revision;
  final Map<String, dynamic> values;

  static const defaults = <String, dynamic>{
    'base_fee': 18000,
    'included_distance_m': 2000,
    'standard_per_km': 5000,
    'rounding_unit': 1000,
    'return_fee_rate_bps': 5000,
    'max_cod': 2000000,
    'max_goods_value': 100000000,
    'max_paid_goods_value': 2000000,
    'topup_min': 5000,
    'topup_max': 10000000,
    'offer_seconds': 45,
    'assignment_minutes': 15,
    'auto_radius_m': 2000,
    'free_pick_radius_m': 3000,
    'company_name': 'GiaoHang',
    'support_phone': '',
    'support_email': 'cskh@gmail.com',
    'customer_individual_fee_bps': 0,
    'customer_business_fee_bps': 0,
    'driver_platform_fee_bps': 0,
  };

  /// Chỉ dùng để đọc snapshot/lịch sử của công thức trước khi bỏ bậc đường dài.
  static const legacyDefaults = <String, dynamic>{
    ...defaults,
    'long_distance_threshold_m': 10000,
    'long_distance_per_km': 4000,
  };

  bool get usesLegacyPricing =>
      values.containsKey('long_distance_threshold_m') &&
      values.containsKey('long_distance_per_km');

  BusinessSettings asSingleRate() => BusinessSettings(
    revision: revision,
    values: Map<String, dynamic>.from(values)
      ..remove('long_distance_threshold_m')
      ..remove('long_distance_per_km'),
  );

  int number(String key) => (values[key] as num).toInt();
  String text(String key) => values[key] as String;
  int get maxCod => number('max_cod');
  int get maxGoodsValue => number('max_goods_value');
  int get maxPaidGoodsValue => number('max_paid_goods_value');
  int get topupMin => number('topup_min');
  int get topupMax => number('topup_max');
  int get autoRadiusMeters => number('auto_radius_m');
  int get freePickRadiusMeters => number('free_pick_radius_m');
  String get companyName => text('company_name');
  String get supportPhone => text('support_phone');
  String get supportEmail => text('support_email');
  int customerPlatformFeeBps(String customerType) => number(
    customerType == 'business'
        ? 'customer_business_fee_bps'
        : 'customer_individual_fee_bps',
  );
  int get driverPlatformFeeBps => number('driver_platform_fee_bps');
  static int calculatePlatformFee(int deliveryFee, int rateBps) =>
      (deliveryFee * rateBps + 5000) ~/ 10000;
  static String formatFeePercent(int bps) =>
      '${(bps / 100).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')}%';
  double returnFee(num deliveryFee) =>
      (deliveryFee * number('return_fee_rate_bps') / 10000).roundToDouble();

  factory BusinessSettings.fromJson(Map<String, dynamic> json) =>
      BusinessSettings(
        revision: (json['revision'] as num).toInt(),
        values: Map<String, dynamic>.from(json['values'] as Map),
      );

  Map<String, dynamic> toJson() => {'revision': revision, 'values': values};
}
