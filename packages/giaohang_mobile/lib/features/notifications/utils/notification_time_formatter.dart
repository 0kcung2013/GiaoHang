import 'package:giaohang_domain/giaohang_domain.dart';

import '../notification_strings.dart';

String formatNotificationTime(DateTime dateTime, {DateTime? now}) {
  final local = VietnamTime.toWallClock(dateTime);
  final current = VietnamTime.now(clock: now);
  final difference = current.difference(local);

  if (difference.inMinutes < 1) return NotificationStrings.justNow;
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes} phút trước';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours} giờ trước';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays} ngày trước';
  }

  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month · $hour:$minute';
}
