/// Read every authorized page using the immutable primary key, so old open
/// cases are not silently excluded by an updated_at/limit(200) snapshot.
Future<List<Map<String, dynamic>>> readCasePages(
  Future<List<Map<String, dynamic>>> Function(String? afterId) load,
) async {
  final rows = <Map<String, dynamic>>[];
  String? cursor;
  while (true) {
    final page = await load(cursor);
    if (page.isEmpty) return rows;
    rows.addAll(page);
    final next = page.last['id'] as String;
    if (next == cursor) throw StateError('Case pagination did not advance');
    cursor = next;
  }
}
