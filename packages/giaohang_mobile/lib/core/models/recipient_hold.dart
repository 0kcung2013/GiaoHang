class RecipientHold {
  const RecipientHold({
    required this.until,
    required this.startedAt,
    required this.state,
    this.returnRequested = false,
  });
  final DateTime until;
  final DateTime startedAt;
  final String state;
  final bool returnRequested;
  bool get isHolding => state == 'holding';
  DateTime get returnEligibleAt => until.add(const Duration(minutes: 5));
  static RecipientHold? fromJson(dynamic value) {
    if (value is! Map) return null;
    final until = DateTime.tryParse('${value['until']}');
    final started = DateTime.tryParse('${value['started_at']}');
    if (until == null || started == null) return null;
    return RecipientHold(
      until: until,
      startedAt: started,
      state: '${value['state']}',
      returnRequested: value['return_report_id'] != null,
    );
  }
}
