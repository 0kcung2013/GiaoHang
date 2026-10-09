import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/support/data/case_pagination.dart';

void main() {
  test(
    'loads cases beyond the first 200 without omitting older cases',
    () async {
      final source = List.generate(
        451,
        (i) => {'id': i.toString().padLeft(4, '0')},
      );
      final result = await readCasePages((cursor) async {
        final start = cursor == null ? 0 : int.parse(cursor) + 1;
        return source.skip(start).take(200).toList();
      });
      expect(result, source);
    },
  );

  test('fails instead of looping forever when the cursor does not advance', () {
    expect(
      readCasePages(
        (_) async => [
          {'id': 'same'},
        ],
      ),
      throwsStateError,
    );
  });
}
