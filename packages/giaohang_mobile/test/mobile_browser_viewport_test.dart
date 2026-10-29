import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_mobile/core/widgets/mobile_browser_viewport.dart';

const _screenKey = ValueKey('screen');
const _dialogKey = ValueKey('dialog');
const _sheetKey = ValueKey('sheet');

void main() {
  for (final entry in {
    const Size(320, 568): const Size(390, 844),
    const Size(390, 844): const Size(390, 844),
    const Size(1280, 640): const Size(390, 844),
    const Size(1920, 1080): const Size(390, 844),
  }.entries) {
    testWidgets('layout and MediaQuery agree at ${entry.key}', (tester) async {
      _setWindowSize(tester, entry.key);
      await _pumpApp(tester);

      final screen = find.byKey(_screenKey);
      expect(tester.getSize(screen), entry.value);
      expect(MediaQuery.sizeOf(tester.element(screen)), entry.value);
      expect(MediaQuery.paddingOf(tester.element(screen)).top, 47);
      expect(MediaQuery.paddingOf(tester.element(screen)).bottom, 34);
      final paintedRect = _globalRect(tester, screen);
      expect(paintedRect.left, greaterThanOrEqualTo(0));
      expect(paintedRect.top, greaterThanOrEqualTo(0));
      expect(paintedRect.right, lessThanOrEqualTo(entry.key.width));
      expect(paintedRect.bottom, lessThanOrEqualTo(entry.key.height));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dialogs and sheets stay inside the mobile viewport', (
    tester,
  ) async {
    _setWindowSize(tester, const Size(1280, 900));
    await _pumpApp(tester);
    final screenRect = _globalRect(tester, find.byKey(_screenKey));

    await tester.tap(find.text('Dialog'));
    await tester.pumpAndSettle();
    final dialog = find.byKey(_dialogKey);
    expect(MediaQuery.sizeOf(tester.element(dialog)), const Size(390, 844));
    expect(screenRect.contains(_globalRect(tester, dialog).topLeft), isTrue);
    expect(
      screenRect.contains(_globalRect(tester, dialog).bottomRight),
      isTrue,
    );
    Navigator.of(tester.element(dialog)).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sheet'));
    await tester.pumpAndSettle();
    final sheetRect = _globalRect(tester, find.byKey(_sheetKey));
    expect(sheetRect.width, closeTo(screenRect.width, 0.01));
    expect(sheetRect.left, closeTo(screenRect.left, 0.01));
    expect(sheetRect.bottom, closeTo(screenRect.bottom, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('resizing the phone preserves form state and logical screen', (
    tester,
  ) async {
    _setWindowSize(tester, const Size(1280, 900));
    await _pumpApp(tester);
    await tester.enterText(find.byType(TextField), 'Delivery address');

    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpAndSettle();
    expect(find.text('Delivery address'), findsOneWidget);
    expect(tester.getSize(find.byKey(_screenKey)), const Size(390, 844));

    tester.view.physicalSize = const Size(1280, 900);
    await tester.pumpAndSettle();
    expect(find.text('Delivery address'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keeps accessibility and fits the phone above the host keyboard',
    (tester) async {
      _setWindowSize(tester, const Size(1280, 900));
      await _pumpApp(
        tester,
        mediaQuery: const MediaQueryData(
          textScaler: TextScaler.linear(1.6),
          disableAnimations: true,
          viewInsets: EdgeInsets.only(bottom: 300),
        ),
      );

      final data = MediaQuery.of(tester.element(find.byKey(_screenKey)));
      expect(data.textScaler.scale(10), 16);
      expect(data.disableAnimations, isTrue);
      expect(data.viewInsets.bottom, 0);
      expect(tester.getSize(find.byKey(_screenKey)), const Size(390, 844));
      expect(_globalRect(tester, find.byKey(_screenKey)).bottom, lessThan(600));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('native apps retain their real viewport and safe areas', (
    tester,
  ) async {
    _setWindowSize(tester, const Size(1024, 768));
    await _pumpApp(
      tester,
      enabled: false,
      mediaQuery: const MediaQueryData(
        size: Size(1024, 768),
        padding: EdgeInsets.only(top: 24, bottom: 20),
        viewPadding: EdgeInsets.only(top: 24, bottom: 20),
      ),
    );

    final data = MediaQuery.of(tester.element(find.byKey(_screenKey)));
    expect(data.size, const Size(1024, 768));
    expect(data.padding, const EdgeInsets.only(top: 24, bottom: 20));
    expect(tester.getSize(find.byKey(_screenKey)), const Size(1024, 768));
  });
}

Rect _globalRect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return Rect.fromPoints(
    box.localToGlobal(Offset.zero),
    box.localToGlobal(box.size.bottomRight(Offset.zero)),
  );
}

void _setWindowSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpApp(
  WidgetTester tester, {
  bool enabled = true,
  MediaQueryData? mediaQuery,
}) => tester.pumpWidget(
  MaterialApp(
    builder: (context, child) {
      final viewport = MobileBrowserViewport(enabled: enabled, child: child!);
      return mediaQuery == null
          ? viewport
          : MediaQuery(data: mediaQuery, child: viewport);
    },
    home: const _TestScreen(),
  ),
);

class _TestScreen extends StatelessWidget {
  const _TestScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    key: _screenKey,
    body: ListView(
      children: [
        const TextField(),
        TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const Dialog(
              child: SizedBox(key: _dialogKey, height: 100, width: 200),
            ),
          ),
          child: const Text('Dialog'),
        ),
        TextButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            builder: (_) => const SizedBox(
              key: _sheetKey,
              height: 100,
              width: double.infinity,
            ),
          ),
          child: const Text('Sheet'),
        ),
      ],
    ),
  );
}
