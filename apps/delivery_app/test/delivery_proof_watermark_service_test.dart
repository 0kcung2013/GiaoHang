import 'package:delivery_app/core/services/delivery_proof_watermark_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';

void main() {
  test('formats the proof timestamp and coordinates consistently', () {
    const location = DeliveryProofLocation(
      latitude: 10.7731234,
      longitude: 106.7039876,
    );

    expect(
      DeliveryProofWatermarkService.formatCapturedAt(
        DateTime(2026, 8, 19, 14, 5, 9),
      ),
      '19/08/2026 14:05:09',
    );
    expect(
      DeliveryProofWatermarkService.formatLocation(location),
      '10.773123, 106.703988',
    );
  });

  test('burns a visible stamp into a JPEG proof image', () async {
    final original = image_lib.Image(width: 800, height: 600);
    image_lib.fill(original, color: image_lib.ColorRgb8(245, 245, 245));
    final source = XFile.fromData(
      image_lib.encodeJpg(original, quality: 90),
      name: 'camera.jpg',
      mimeType: 'image/jpeg',
    );

    final stamped = await const DeliveryProofWatermarkService().apply(
      source: source,
      capturedAt: DateTime(2026, 8, 19, 14, 5, 9),
      location: const DeliveryProofLocation(
        latitude: 10.7731234,
        longitude: 106.7039876,
      ),
      address: '12 Nguyễn Huệ, Quận 1, Hồ Chí Minh',
    );
    final stampedBytes = await stamped.readAsBytes();
    final decoded = image_lib.decodeJpg(stampedBytes);

    expect(stamped.mimeType, 'image/jpeg');
    expect(stampedBytes, isNotEmpty);
    expect(decoded, isNotNull);
    expect(decoded!.width, 800);
    expect(decoded.height, 600);

    final stampPixel = decoded.getPixel(40, 520);
    expect(stampPixel.b, lessThan(150));
  });
}
