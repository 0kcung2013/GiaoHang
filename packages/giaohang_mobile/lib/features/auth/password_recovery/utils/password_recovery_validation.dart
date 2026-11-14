import '../password_recovery_strings.dart';

String? validateRecoveryEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return PasswordRecoveryStrings.missingEmail;
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    return PasswordRecoveryStrings.invalidEmail;
  }
  return null;
}

String? validateRecoveryCode(String? value) =>
    RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')
    ? null
    : PasswordRecoveryStrings.invalidCode;

String? validateRecoveryPassword(String? value) =>
    value == null || value.length < 6
    ? PasswordRecoveryStrings.invalidPassword
    : null;
