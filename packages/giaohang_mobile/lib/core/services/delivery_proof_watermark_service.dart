import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';

import 'package:giaohang_design/giaohang_design.dart';

class DeliveryProofLocation {
  const DeliveryProofLocation({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

class DeliveryProofCapture {
  const DeliveryProofCapture({
    required this.image,
    required this.capturedAt,
    required this.location,
    required this.address,
  });

  final XFile image;
  final DateTime capturedAt;
  final DeliveryProofLocation location;
  final String address;
}

typedef DeliveryProofLocationProvider = DeliveryProofLocation? Function();
typedef DeliveryProofAddressResolver =
    Future<String?> Function(DeliveryProofLocation location);

typedef DeliveryProofWatermarker =
    Future<XFile> Function({
      required XFile source,
      required DateTime capturedAt,
      required DeliveryProofLocation location,
      required String address,
    });

class DeliveryProofWatermarkException implements Exception {
  const DeliveryProofWatermarkException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DeliveryProofWatermarkService {
  const DeliveryProofWatermarkService();

  static const int maxImageEdge = 1600;
  static const int jpegQuality = 86;

  Future<XFile> apply({
    required XFile source,
    required DateTime capturedAt,
    required DeliveryProofLocation location,
    required String address,
  }) async {
    final sourceBytes = await source.readAsBytes();
    if (sourceBytes.isEmpty) {
      throw const DeliveryProofWatermarkException(
        'Ảnh vừa chụp bị trống. Vui lòng chụp lại.',
      );
    }

    try {
      final outputBytes = await _renderWatermark(
        sourceBytes: sourceBytes,
        capturedAt: capturedAt,
        location: location,
        address: address,
      );
      return XFile.fromData(
        outputBytes,
        name: 'delivery_proof_${capturedAt.millisecondsSinceEpoch}.jpg',
        mimeType: 'image/jpeg',
      );
    } catch (_) {
      throw const DeliveryProofWatermarkException(
        'Không thể đóng dấu thời gian và vị trí lên ảnh. Vui lòng chụp lại.',
      );
    }
  }

  static String formatCapturedAt(DateTime value) {
    return '${_twoDigits(value.day)}/${_twoDigits(value.month)}/${value.year} '
        '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}:'
        '${_twoDigits(value.second)}';
  }

  static String formatLocation(DeliveryProofLocation value) {
    return '${value.latitude.toStringAsFixed(6)}, '
        '${value.longitude.toStringAsFixed(6)}';
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

Future<Uint8List> _renderWatermark({
  required Uint8List sourceBytes,
  required DateTime capturedAt,
  required DeliveryProofLocation location,
  required String address,
}) async {
  final codec = await ui.instantiateImageCodec(sourceBytes);
  ui.Image? sourceImage;
  ui.Image? stampedImage;
  try {
    sourceImage = (await codec.getNextFrame()).image;
    final longestEdge = sourceImage.width > sourceImage.height
        ? sourceImage.width
        : sourceImage.height;
    final scale = longestEdge > DeliveryProofWatermarkService.maxImageEdge
        ? DeliveryProofWatermarkService.maxImageEdge / longestEdge
        : 1.0;
    final targetWidth = (sourceImage.width * scale).round();
    final targetHeight = (sourceImage.height * scale).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      sourceImage,
      Rect.fromLTWH(
        0,
        0,
        sourceImage.width.toDouble(),
        sourceImage.height.toDouble(),
      ),
      Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
    _drawProofStamp(
      canvas,
      width: targetWidth.toDouble(),
      height: targetHeight.toDouble(),
      capturedAt: capturedAt,
      location: location,
      address: address,
    );

    stampedImage = await recorder.endRecording().toImage(
      targetWidth,
      targetHeight,
    );
    final rgba = await stampedImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (rgba == null) throw StateError('Unable to encode proof image');

    return compute(_encodeJpeg, <String, Object>{
      'bytes': rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes),
      'width': targetWidth,
      'height': targetHeight,
    });
  } finally {
    stampedImage?.dispose();
    sourceImage?.dispose();
    codec.dispose();
  }
}

Uint8List _encodeJpeg(Map<String, Object> payload) {
  final rgba = payload['bytes']! as Uint8List;
  final image = image_lib.Image.fromBytes(
    width: payload['width']! as int,
    height: payload['height']! as int,
    bytes: rgba.buffer,
    bytesOffset: rgba.offsetInBytes,
    order: image_lib.ChannelOrder.rgba,
  );
  return Uint8List.fromList(
    image_lib.encodeJpg(
      image,
      quality: DeliveryProofWatermarkService.jpegQuality,
    ),
  );
}

void _drawProofStamp(
  Canvas canvas, {
  required double width,
  required double height,
  required DateTime capturedAt,
  required DeliveryProofLocation location,
  required String address,
}) {
  final fontSize = width >= 1200
      ? 36.0
      : width >= 560
      ? 22.0
      : 14.0;
  final margin = (width * 0.025).clamp(8.0, 40.0);
  final padding = (fontSize * 0.75).clamp(8.0, 28.0);
  final railWidth = (fontSize * 0.22).clamp(3.0, 9.0);
  final textX = margin + padding + railWidth + padding;
  final textMaxWidth = width - textX - margin - padding;
  final normalizedAddress = address.trim().isEmpty
      ? 'Không xác định được địa chỉ'
      : address.trim();
  final painter = TextPainter(
    text: TextSpan(
      text:
          'TIME  ${DeliveryProofWatermarkService.formatCapturedAt(capturedAt)}\n'
          'GPS   ${DeliveryProofWatermarkService.formatLocation(location)}\n'
          'ĐỊA CHỈ  $normalizedAddress',
      style: TextStyle(
        color: AppColors.textOnDark,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1.28,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 4,
    ellipsis: '…',
  )..layout(maxWidth: textMaxWidth);

  final barHeight = painter.height + (padding * 2);
  final barTop = (height - margin - barHeight).clamp(0.0, height);
  final barRect = RRect.fromRectAndRadius(
    Rect.fromLTRB(margin, barTop, width - margin, height - margin),
    Radius.circular((fontSize * 0.6).clamp(8.0, 22.0)),
  );
  canvas.drawRRect(
    barRect,
    Paint()..color = AppColors.primary.withValues(alpha: 0.88),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
        margin + padding,
        barTop + padding,
        railWidth,
        painter.height,
      ),
      Radius.circular(railWidth),
    ),
    Paint()..color = AppColors.accent,
  );
  painter.paint(canvas, Offset(textX, barTop + padding));
  painter.dispose();
}
