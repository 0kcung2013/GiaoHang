import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Optional local screenshot fonts; no network fetch during widget capture.
Future<void> prepareUtrafficCaptureFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  final configFile = File('../../.dart_tool/package_config.json');
  final config = jsonDecode(await configFile.readAsString()) as Map;
  final flutterPackage = (config['packages'] as List).firstWhere(
    (p) => p['name'] == 'flutter',
  );
  final uri = configFile.absolute.uri.resolve('${flutterPackage['rootUri']}/');
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      File.fromUri(
        uri.resolve(
          '../../bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ),
      ).readAsBytes().then(ByteData.sublistView),
    );
  await icons.load();
  final fallback = await File.fromUri(
    uri.resolve('../flutter_tools/static/Ahem.ttf'),
  ).readAsBytes();
  const variants = ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'];
  final bytes = <String, ByteData>{};
  for (final variant in variants) {
    final file = File('../../.tmp/PlusJakartaSans-$variant.ttf');
    final regular = File('../../.tmp/PlusJakartaSans-Regular.ttf');
    bytes['fonts/PlusJakartaSans-$variant.ttf'] = ByteData.sublistView(
      file.existsSync()
          ? await file.readAsBytes()
          : regular.existsSync()
          ? await regular.readAsBytes()
          : fallback,
    );
  }
  final mono = File('../../.tmp/JetBrainsMono-Medium.ttf');
  bytes['fonts/JetBrainsMono-Medium.ttf'] = ByteData.sublistView(
    mono.existsSync() ? await mono.readAsBytes() : fallback,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        if (key == 'AssetManifest.bin') {
          return const StandardMessageCodec().encodeMessage({
            for (final key in bytes.keys)
              key: [
                {'asset': key},
              ],
          });
        }
        if (bytes.containsKey(key)) return bytes[key];
        const mobilePrefix = 'packages/giaohang_mobile/';
        final file = File(
          key.startsWith(mobilePrefix)
              ? key.substring(mobilePrefix.length)
              : key,
        );
        return file.existsSync()
            ? ByteData.sublistView(await file.readAsBytes())
            : null;
      });
  for (final weight in [
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
    FontWeight.w800,
  ]) {
    GoogleFonts.plusJakartaSans(fontWeight: weight);
  }
  GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w500);
  await GoogleFonts.pendingFonts();
}
