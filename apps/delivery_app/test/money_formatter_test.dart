import 'package:delivery_app/core/utils/money_formatter.dart';
import 'package:delivery_app/core/utils/vnd_input_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats VND with a dot between every three digits', () {
    expect(formatVnd(1000), '1.000đ');
    expect(formatVnd(100000), '100.000đ');
    expect(formatVnd(1234567), '1.234.567đ');
    expect(formatVnd(-350000), '-350.000đ');
  });

  test('formats money while typing and keeps the cursor at the end', () {
    const formatter = VndInputFormatter();
    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '100000'),
    );

    expect(result.text, '100.000');
    expect(result.selection.baseOffset, result.text.length);
    expect(parseVndInput(result.text), 100000);
  });
}
