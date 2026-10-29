import '../constants/account_strings.dart';

class AccountUi {
  static String date(DateTime value) {
    final local = value.toLocal();
    String pad(int number) => number.toString().padLeft(2, '0');
    return '${pad(local.day)}/${pad(local.month)}/${local.year} ${pad(local.hour)}:${pad(local.minute)}';
  }

  static String until(DateTime? value) =>
      value == null ? AccountStrings.permanent : 'Đến ${date(value)}';
}
