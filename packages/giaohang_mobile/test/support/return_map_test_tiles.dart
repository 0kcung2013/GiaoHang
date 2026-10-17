import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';

/// Keep the production map/camera/marker tree; tiles do not need a network.
class ReturnMapTestTiles extends TileProvider {
  static late MemoryImage _image;

  static Future<void> prepare() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const Color(0x00000000), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(1, 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    _image = MemoryImage(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _image;
}
