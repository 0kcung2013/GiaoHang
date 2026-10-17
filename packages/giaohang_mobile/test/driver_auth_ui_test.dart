import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:giaohang_mobile/features/auth/screens/driver_auth/driver_auth_screen.dart';
import 'package:giaohang_mobile/features/auth/screens/driver_auth/driver_auth_strings.dart';
import 'package:giaohang_mobile/features/auth/screens/driver_auth/widgets/driver_auth_feedback.dart';
import 'package:giaohang_mobile/features/auth/screens/driver_auth/widgets/driver_document_picker.dart';
import 'package:giaohang_mobile/features/auth/screens/driver_auth/wizard/driver_confirmation_step.dart';
import 'package:giaohang_mobile/features/auth/screens/driver_auth/wizard/driver_documents_step.dart';
import 'package:giaohang_mobile/features/auth/screens/driver_auth/wizard/driver_identity_steps.dart';
import 'package:giaohang_mobile/features/auth/screens/driver_auth/wizard/driver_register_data.dart';
import 'package:giaohang_mobile/features/auth/screens/driver_auth/wizard/driver_register_prefill.dart';
import 'package:giaohang_mobile/features/auth/screens/driver_auth/wizard/driver_register_wizard.dart';
import 'package:giaohang_mobile/features/auth/screens/driver_auth/wizard/driver_vehicle_step.dart';

void main() {
  Completer<http.Response>? pendingLogin;
  var loginRequests = 0;

  setUpAll(() async {
    // Behavioral tests use an SDK font; visual previews load the actual brand font.
    GoogleFonts.config.allowRuntimeFetching = false;
    final font = File.fromUri(
      File(
        Platform.resolvedExecutable,
      ).parent.uri.resolve('../../material_fonts/roboto-regular.ttf'),
    ).readAsBytesSync();
    const fontNames = ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key == 'AssetManifest.bin') {
            return const StandardMessageCodec().encodeMessage({
              for (final weight in fontNames)
                'PlusJakartaSans-$weight.ttf': [
                  {'asset': 'PlusJakartaSans-$weight.ttf'},
                ],
            });
          }
          if (key.endsWith('.ttf')) return ByteData.sublistView(font);
          const prefix = 'packages/giaohang_mobile/';
          if (key.startsWith(prefix)) {
            return ByteData.sublistView(
              File(key.substring(prefix.length)).readAsBytesSync(),
            );
          }
          return null;
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
    await GoogleFonts.pendingFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/token')) {
          loginRequests++;
          return pendingLogin!.future;
        }
        return http.Response('{}', 200);
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  setUp(() {
    pendingLogin = Completer<http.Response>();
    loginRequests = 0;
  });

  testWidgets(
    'login validates, reveals password, blocks duplicate submits and shows auth error',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      await tester.pumpWidget(_app(const DriverAuthScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text(DriverAuthStrings.missingEmail), findsOneWidget);
      expect(find.text(DriverAuthStrings.missingPassword), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        'driver@example.com',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'secret-password',
      );
      await tester.tap(find.byTooltip(DriverAuthStrings.showPassword));
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
        isFalse,
      );
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(find.text(DriverAuthStrings.loggingIn), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
        isFalse,
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() async {
        pendingLogin!.complete(
          http.Response(
            jsonEncode({
              'msg': 'Invalid login credentials',
              'code': 'invalid_credentials',
            }),
            400,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(loginRequests, 1);
      expect(find.text(DriverAuthStrings.invalidCredentials), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'short phone keeps focused email when keyboard opens and text is enlarged',
    (tester) async {
      _viewport(tester, const Size(320, 568));
      await tester.pumpWidget(_app(const DriverAuthScreen(), scale: 1.6));
      await tester.pumpAndSettle();
      final email = find.byType(TextFormField).first;
      await tester.ensureVisible(email);
      await tester.enterText(email, 'driver@example.com');
      final editable = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      expect(editable.focusNode.hasFocus, isTrue);
      expect(editable.controller.text, 'driver@example.com');
      await tester.ensureVisible(find.byType(FilledButton));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'registration retains account data across steps and shows errors beside inputs',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      await tester.pumpWidget(_app(const DriverAuthScreen(register: true)));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text(DriverAuthStrings.invalidEmail), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        'driver@example.com',
      );
      await tester.enterText(find.byType(TextFormField).last, '12345');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text(DriverAuthStrings.shortPassword), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).last, '123456');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.byType(DriverPersonalStep), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, 'Nguyễn Văn An');
      await tester.tap(find.byTooltip(DriverAuthStrings.back));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .controller
            .text,
        'driver@example.com',
      );
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).last)
            .controller
            .text,
        '123456',
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .controller
            .text,
        'Nguyễn Văn An',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'prefill skips account and stays usable with short viewport and keyboard',
    (tester) async {
      _viewport(tester, const Size(320, 568));
      await tester.pumpWidget(
        _app(
          const Scaffold(
            body: SafeArea(
              child: DriverRegisterWizard(
                prefill: DriverRegisterPrefill(
                  email: 'driver@example.com',
                  password: '123456',
                  fullName: 'Nguyễn Văn An',
                ),
              ),
            ),
          ),
          scale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DriverAccountStep), findsNothing);
      expect(find.textContaining('Bước 1/4'), findsOneWidget);
      await tester.ensureVisible(find.byType(TextFormField).first);
      await tester.tap(find.byType(TextFormField).first);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(FilledButton));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('registration route and return to login remain available', (
    tester,
  ) async {
    _viewport(tester, const Size(390, 844));
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, state) => const DriverAuthScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (_, state) => const DriverAuthScreen(register: true),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(DriverAuthStrings.register));
    await tester.tap(find.text(DriverAuthStrings.register));
    await tester.pumpAndSettle();
    expect(find.byType(DriverRegisterWizard), findsOneWidget);
    await tester.tap(find.byTooltip(DriverAuthStrings.backToLogin));
    await tester.pumpAndSettle();
    expect(find.text(DriverAuthStrings.loginTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
    const Size(1440, 900),
  ]) {
    testWidgets('all registration sections fit $size at enlarged text', (
      tester,
    ) async {
      _viewport(tester, size);
      final data = DriverRegisterData();
      for (final section in [
        DriverVehicleStep(data: data),
        DriverDocumentsStep(data: data, onPick: (_) {}),
        DriverConfirmationStep(data: data),
      ]) {
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: section,
                    ),
                  ),
                ),
              ),
            ),
            scale: 1.6,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets(
    'selected document preview updates immediately and can be replaced',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      // Valid 1x1 PNG avoids disk and platform picker dependencies.
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=',
      );
      XFile? file;
      var picks = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => DriverDocumentPicker(
                label: DriverAuthStrings.idFront,
                icon: Icons.badge_rounded,
                file: file,
                onTap: () => setState(() {
                  picks++;
                  file = XFile.fromData(bytes, name: 'id-$picks.png');
                }),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(InkWell));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(find.text(DriverAuthStrings.changePhoto), findsOneWidget);
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(picks, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'full registration keeps focused email above footer on small phone',
    (tester) async {
      _viewport(tester, const Size(320, 568));
      await tester.pumpWidget(
        _app(const DriverAuthScreen(register: true), scale: 1.6),
      );
      await tester.pumpAndSettle();
      final email = find.byType(TextFormField).first;
      await tester.ensureVisible(email);
      await tester.enterText(email, 'driver@example.com');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      await tester.ensureVisible(email);
      final editable = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      expect(editable.focusNode.hasFocus, isTrue);
      expect(editable.controller.text, 'driver@example.com');
      expect(
        tester.getBottomLeft(email).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(DriverAuthButton)).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('loading CTA exposes progress and disables interaction', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: DriverAuthButton(
            label: DriverAuthStrings.submit,
            loading: true,
            loadingLabel: DriverAuthStrings.submitting,
            onPressed: () {},
          ),
        ),
      ),
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.text(DriverAuthStrings.submitting), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

void _viewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetViewInsets);
}

Widget _app(Widget home, {double scale = 1}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
    child: child!,
  ),
  home: home,
);
