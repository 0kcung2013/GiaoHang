import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/auth/operations_account_aliases.dart';

void main() {
  test('resolves the admin alias to the existing auth email', () {
    expect(
      resolveOperationsLogin(' Admin '),
      '2224802010601@student.tdmu.edu.vn',
    );
  });

  test('resolves support alias and normalizes email input', () {
    expect(resolveOperationsLogin('cskh'), 'cskh@gmail.com');
    expect(resolveOperationsLogin(' CSKH@GMAIL.COM '), 'cskh@gmail.com');
  });
}
