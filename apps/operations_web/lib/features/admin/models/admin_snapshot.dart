enum AdminMetric {
  orders('Tổng đơn hàng'),
  waiting('Chưa phân công'),
  active('Đang thực hiện'),
  delivered('Đã giao thành công'),
  drivers('Tài xế'),
  customers('Khách hàng'),
  kyc('Hồ sơ KYC'),
  changes('Thay đổi hồ sơ'),
  disabledAccounts('Tài khoản vô hiệu hóa');

  const AdminMetric(this.label);
  final String label;
}

class AdminSnapshot {
  const AdminSnapshot({required this.values, required this.updatedAt});
  final Map<AdminMetric, int?> values;
  final DateTime updatedAt;
  bool get hasErrors => AdminMetric.values.any((m) => values[m] == null);
  int? operator [](AdminMetric metric) => values[metric];
}

/// Projection chỉ dùng cho danh bạ quản trị; không chứa thông tin xác thực.
class AdminAccount {
  const AdminAccount({
    required this.id,
    required this.name,
    required this.role,
    this.email,
    this.phone,
    this.createdAt,
  });
  final String id;
  final String name;
  final String role;
  final String? email;
  final String? phone;
  final DateTime? createdAt;
  factory AdminAccount.fromJson(Map<String, dynamic> row) => AdminAccount(
    id: row['id'].toString(),
    name: row['full_name']?.toString() ?? '',
    role: row['role']?.toString() ?? '',
    email: row['email']?.toString(),
    phone: row['phone']?.toString(),
    createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': name,
    'role': role,
    'email': email,
    'phone': phone,
    'created_at': createdAt?.toIso8601String(),
  };
}
