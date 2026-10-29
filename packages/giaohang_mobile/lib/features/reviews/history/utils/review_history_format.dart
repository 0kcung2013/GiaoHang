import '../../../../core/models/review_model.dart';

String reviewHistoryDate(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year}'
      ' · ${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

String reviewHistoryTag(String id) =>
    customerDriverReviewTags
        .where((option) => option.id == id)
        .map((option) => option.label)
        .firstOrNull ??
    id;
