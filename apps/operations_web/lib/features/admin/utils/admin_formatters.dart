String formatAdminCount(int? value) {
  if (value == null) return '—';
  return value.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );
}
