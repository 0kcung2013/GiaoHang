import 'package:giaohang_storage/giaohang_storage.dart';
import 'package:test/test.dart';

void main() {
  test('nhận diện và tách R2 object reference', () {
    const value = 'r2://media/users/u-1/avatar/photo.jpg';

    expect(R2ObjectReference.isR2(value), isTrue);
    expect(R2ObjectReference.bucket(value), 'media');
    expect(R2ObjectReference.key(value), 'users/u-1/avatar/photo.jpg');
  });

  test('không nhận URL cũ là R2 reference', () {
    expect(R2ObjectReference.isR2('https://example.com/photo.jpg'), isFalse);
    expect(R2ObjectReference.isR2(null), isFalse);
  });
}
