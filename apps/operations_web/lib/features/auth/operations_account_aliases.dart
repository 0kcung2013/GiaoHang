const _operationsAccountAliases = <String, String>{
  'admin': '2224802010601@student.tdmu.edu.vn',
  'cskh': 'cskh@gmail.com',
};

/// Chuyển bí danh nội bộ thành email Supabase Auth tương ứng.
String resolveOperationsLogin(String input) {
  final normalized = input.trim().toLowerCase();
  return _operationsAccountAliases[normalized] ?? normalized;
}
