String formatOrderContactTime(DateTime sentAt) {
  final localTime = sentAt.toLocal();
  final hour = localTime.hour.toString().padLeft(2, '0');
  final minute = localTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
