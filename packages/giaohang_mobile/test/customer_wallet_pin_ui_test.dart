import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_mobile/core/models/customer_wallet_pin.dart';
import 'package:giaohang_mobile/core/services/customer_wallet_pin_service.dart';
import 'package:giaohang_mobile/features/customer/wallet_pin/customer_wallet_payment_pin_sheet.dart';
import 'package:giaohang_mobile/features/customer/wallet_pin/customer_wallet_pin_setup_screen.dart';
import 'package:giaohang_mobile/features/customer/wallet_pin/customer_wallet_pin_recovery_screen.dart';
import 'package:giaohang_mobile/features/customer/wallet_pin/customer_wallet_pin_strings.dart';

import 'helpers/utraffic_capture_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(prepareUtrafficCaptureFonts);

  testWidgets('six digits require explicit confirmation and preserve zeroes', (
    tester,
  ) async {
    final pins = <String>[];
    final pending = Completer<void>();
    await tester.pumpWidget(
      _payment(
        onConfirm: (pin) {
          pins.add(pin);
          return pending.future;
        },
      ),
    );
    await tester.enterText(_input('wallet-payment-pin'), '001234');
    await tester.pump();
    expect(pins, isEmpty);
    expect(
      tester.widget<TextField>(_input('wallet-payment-pin')).obscureText,
      isTrue,
    );
    await tester.tap(
      find.widgetWithText(
        FilledButton,
        CustomerWalletPinStrings.confirmPayment,
      ),
    );
    await tester.pump();
    expect(pins, ['001234']);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    pending.complete();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'wrong PIN stays open, clears digits and permits another attempt',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        _payment(
          onConfirm: (_) async {
            attempts++;
            throw CustomerWalletPinException.fromJson({
              'code': 'PIN_INVALID',
              'attempts_remaining': 4,
            });
          },
        ),
      );
      await tester.enterText(_input('wallet-payment-pin'), '123456');
      await tester.pump();
      await tester.tap(
        find.widgetWithText(
          FilledButton,
          CustomerWalletPinStrings.confirmPayment,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('4 lần thử'), findsOneWidget);
      expect(
        tester.widget<TextField>(_input('wallet-payment-pin')).controller!.text,
        isEmpty,
      );
      expect(attempts, 1);
    },
  );

  testWidgets('server lock disables input and keeps recovery available', (
    tester,
  ) async {
    await tester.pumpWidget(
      _payment(
        status: CustomerWalletPinStatus(
          isConfigured: true,
          attemptsRemaining: 0,
          serverNow: DateTime.utc(2026),
          lockedUntil: DateTime.utc(2026).add(const Duration(seconds: 2)),
        ),
      ),
    );
    expect(
      tester.widget<TextField>(_input('wallet-payment-pin')).enabled,
      isFalse,
    );
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, CustomerWalletPinStrings.forgot),
          )
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('mismatching setup never calls the server', (tester) async {
    var saves = 0;
    final service = CustomerWalletPinService(
      rpcInvoker: (_, _) async {
        saves++;
        return {'ok': true};
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerWalletPinSetupScreen(
          service: service,
          isConfigured: false,
        ),
      ),
    );
    await tester.enterText(_input('wallet-pin-new'), '001234');
    await tester.enterText(_input('wallet-pin-confirm'), '001235');
    await tester.ensureVisible(find.text(CustomerWalletPinStrings.save));
    await tester.tap(find.text(CustomerWalletPinStrings.save));
    await tester.pumpAndSettle();
    expect(find.text(CustomerWalletPinStrings.mismatch), findsOneWidget);
    expect(saves, 0);
  });

  testWidgets('recovery sends email then passes code and matching new PIN', (
    tester,
  ) async {
    var sent = 0;
    final resets = <(String, String)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerWalletPinRecoveryScreen(
          email: 'customer@example.test',
          onSend: () async {
            sent++;
          },
          onReset: (code, pin) async {
            resets.add((code, pin));
          },
        ),
      ),
    );
    await tester.tap(find.text(CustomerWalletPinStrings.sendCode));
    await tester.pumpAndSettle();
    expect(sent, 1);
    await tester.enterText(_input('wallet-pin-email-code'), '654321');
    await tester.enterText(_input('wallet-pin-recovery-new'), '001234');
    await tester.enterText(_input('wallet-pin-recovery-confirm'), '001234');
    await tester.ensureVisible(find.text(CustomerWalletPinStrings.save));
    await tester.tap(find.text(CustomerWalletPinStrings.save));
    await tester.pumpAndSettle();
    expect(resets, [('654321', '001234')]);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(1200, 800),
  ]) {
    testWidgets('PIN fits $size with keyboard and large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _payment(
          media: MediaQueryData(
            size: size,
            textScaler: const TextScaler.linear(1.6),
            viewInsets: const EdgeInsets.only(bottom: 220),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(CustomerWalletPinStrings.cancel));
      expect(tester.takeException(), isNull);
    });
  }

  if (const bool.fromEnvironment('CAPTURE_WALLET_PIN')) {
    testWidgets('capture payment PIN for visual review', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(_payment(capture: key));
      await tester.enterText(_input('wallet-payment-pin'), '001234');
      await tester.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = Directory('../../artifacts/wallet_pin')
          ..createSync(recursive: true);
        await File(
          '${output.path}/payment_pin.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}

Finder _input(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(TextField),
);

Widget _payment({
  Future<void> Function(String)? onConfirm,
  CustomerWalletPinStatus? status,
  MediaQueryData? media,
  GlobalKey? capture,
}) => MaterialApp(
  home: MediaQuery(
    data: media ?? const MediaQueryData(size: Size(390, 844)),
    child: Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: RepaintBoundary(
        key: capture,
        child: ColoredBox(
          color: Colors.white,
          child: CustomerWalletPaymentPinSheet(
            status:
                status ??
                CustomerWalletPinStatus(
                  isConfigured: true,
                  attemptsRemaining: 5,
                  serverNow: DateTime.utc(2026),
                ),
            amount: 18900,
            balance: 100000,
            onConfirm: onConfirm ?? (_) async {},
            onRecover: () async => false,
          ),
        ),
      ),
    ),
  ),
);
