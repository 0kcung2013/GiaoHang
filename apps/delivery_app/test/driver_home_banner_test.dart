import 'package:delivery_app/features/driver/screens/home/driver_home_strings.dart';
import 'package:delivery_app/features/driver/screens/home/widgets/driver_home_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('driver home banner shows the online idle message', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(375, 812));

    await tester.pumpWidget(
      const _BannerPreview(isOnline: true, textScaler: TextScaler.noScaling),
    );
    await tester.pumpAndSettle();

    expect(find.text(DriverHomeStrings.bannerTitle), findsOneWidget);
    expect(find.text(DriverHomeStrings.bannerOnlineSubtitle), findsOneWidget);
    expect(
      find.bySemanticsLabel(DriverHomeStrings.bannerSemanticLabel),
      findsOneWidget,
    );
    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    final resizedImage = image.image as ResizeImage;
    expect(
      (resizedImage.imageProvider as AssetImage).assetName,
      'assets/images/driver_home_courier_banner_v2.png',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('driver home banner supports large accessible text', (
    tester,
  ) async {
    await _setTestViewport(tester, const Size(375, 812));

    await tester.pumpWidget(
      const _BannerPreview(isOnline: false, textScaler: TextScaler.linear(1.6)),
    );
    await tester.pumpAndSettle();

    expect(find.text(DriverHomeStrings.bannerOfflineSubtitle), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'banner must not overflow');
  });

  testWidgets('driver home banner remains stable in landscape', (tester) async {
    await _setTestViewport(tester, const Size(812, 375));

    await tester.pumpWidget(
      const _BannerPreview(isOnline: true, textScaler: TextScaler.noScaling),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setTestViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

class _BannerPreview extends StatelessWidget {
  const _BannerPreview({required this.isOnline, required this.textScaler});

  final bool isOnline;
  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: DriverHomeBanner(isOnline: isOnline),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
