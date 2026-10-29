import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_mobile/core/mobile_app_role.dart';
import 'package:giaohang_mobile/core/mobile_route_policy.dart';
import 'package:giaohang_mobile/core/models/user_model.dart';
import 'package:giaohang_mobile/core/providers/business_settings_providers.dart';
import 'package:giaohang_mobile/core/widgets/platform_fee_card.dart';
import 'package:giaohang_mobile/features/customer/screens/account/constants/customer_classification_strings.dart';
import 'package:giaohang_mobile/features/customer/screens/account/data/customer_classification_repository.dart';
import 'package:giaohang_mobile/features/customer/screens/account/widgets/customer_classification_form.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'helpers/customer_account_fixtures.dart';
import 'review_service_test.dart' show reviewTestClient, response;

class _Repository implements CustomerClassificationRepository {
  bool fail = true;
  String? savedType, savedName;
  @override
  Future<UserModel> save({
    required String userId,
    required String type,
    String? businessName,
    String? businessAddress,
    String? taxCode,
  }) async {
    savedType = type;
    savedName = businessName;
    if (fail) throw Exception('offline');
    return UserModel.fromJson({
      ...customerAccountFixture.toJson(),
      'customer_type': type,
      'business_name': businessName,
      'business_address': businessAddress,
      'business_tax_code': taxCode,
    });
  }
}

void main() {
  setUpAll(() async {
    await loadCustomerAccountTestFonts();
    final icons = File.fromUri(
      File(
        Platform.resolvedExecutable,
      ).parent.uri.resolve('../../material_fonts/materialicons-regular.otf'),
    );
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  });

  test(
    'classification update is owner-scoped and switching clears business data',
    () async {
      final client = await reviewTestClient((request) {
        expect(request.method, 'PATCH');
        expect(request.url.queryParameters['id'], 'eq.actor-1');
        expect(request.url.queryParameters['role'], 'eq.customer');
        expect(jsonDecode(request.body), {
          'customer_type': 'individual',
          'business_name': null,
          'business_address': null,
          'business_tax_code': null,
        });
        return response(request, {
          ...customerAccountFixture.toJson(),
          'customer_type': 'individual',
        });
      });
      addTearDown(client.dispose);
      final repository = SupabaseCustomerClassificationRepository(client);
      final saved = await repository.save(
        userId: 'actor-1',
        type: 'individual',
        businessName: 'Old shop',
        businessAddress: 'Old address',
        taxCode: '1234567890',
      );
      expect(saved.customerType, 'individual');
      await expectLater(
        repository.save(userId: 'another-user', type: 'individual'),
        throwsA(isA<AuthException>()),
      );
    },
  );

  test(
    'classification round trips and incomplete businesses stay incomplete',
    () {
      expect(customerAccountFixture.hasCustomerClassification, isFalse);
      final individual = UserModel.fromJson({
        ...customerAccountFixture.toJson(),
        'customer_type': 'individual',
      });
      expect(individual.hasCustomerClassification, isTrue);
      final incomplete = UserModel.fromJson({
        ...individual.toJson(),
        'customer_type': 'business',
      });
      expect(incomplete.hasCustomerClassification, isFalse);
      final business = UserModel.fromJson({
        ...incomplete.toJson(),
        'business_name': 'Shop An',
        'business_address': '123 Nguyễn Trãi',
      });
      expect(
        UserModel.fromJson(business.toJson()).hasCustomerClassification,
        isTrue,
      );
    },
  );

  test('customer onboarding respects role gates and completed profiles', () {
    String? redirect(
      String location, {
      bool complete = false,
      String role = 'customer',
    }) => mobileRouteRedirect(
      app: MobileAppRole.customer,
      location: location,
      signedIn: true,
      accountRole: role,
      customerClassified: complete,
    );
    expect(redirect('/customer-home'), '/customer-classification');
    expect(redirect('/customer/create-order'), '/customer-classification');
    expect(redirect('/customer-classification'), isNull);
    expect(redirect('/help'), isNull);
    expect(redirect('/customer-home', complete: true), isNull);
    expect(
      redirect('/customer-classification', complete: true),
      '/customer-home',
    );
    expect(redirect('/customer-home', role: 'driver'), '/unsupported-role');
    expect(
      mobileRouteRedirect(
        app: MobileAppRole.customer,
        location: '/customer-classification',
        signedIn: false,
        customerClassified: false,
      ),
      '/login',
    );
  });

  testWidgets(
    'business validates and preserves inputs after save failure on a short viewport',
    (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repository();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerClassificationRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: ThemeData(
              fontFamily: AppTextStyles.bodyMedium.fontFamily,
              scaffoldBackgroundColor: AppColors.bgLight,
            ),
            home: RepaintBoundary(
              key: boundary,
              child: Scaffold(
                body: SafeArea(
                  child: CustomerClassificationForm(
                    profile: customerAccountFixture,
                    onboarding: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(CustomerClassificationStrings.business));
      await tester.pumpAndSettle();
      final capture = Platform.environment['GIAOHANG_UI_CAPTURE'];
      if (capture != null) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(capture).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.ensureVisible(find.text(CustomerClassificationStrings.save));
      await tester.tap(find.text(CustomerClassificationStrings.save));
      await tester.pumpAndSettle();
      expect(
        find.text(CustomerClassificationStrings.nameError),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'Shop An');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        '123 Nguyễn Trãi',
      );
      await tester.ensureVisible(find.text(CustomerClassificationStrings.save));
      await tester.tap(find.text(CustomerClassificationStrings.save));
      await tester.pumpAndSettle();
      expect(
        find.text(CustomerClassificationStrings.saveError),
        findsOneWidget,
      );
      expect(repo.savedType, 'business');
      expect(repo.savedName, 'Shop An');
      expect(find.text('123 Nguyễn Trãi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('classification remains usable with enlarged text and keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(375, 667),
              textScaler: TextScaler.linear(1.6),
              viewInsets: EdgeInsets.only(bottom: 280),
            ),
            child: Scaffold(
              body: CustomerClassificationForm(
                profile: customerAccountFixture,
                onboarding: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text(CustomerClassificationStrings.business));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextFormField).first);
    await tester.enterText(find.byType(TextFormField).first, 'Shop có tên dài');
    await tester.ensureVisible(find.text(CustomerClassificationStrings.save));
    expect(
      find.text(CustomerClassificationStrings.save).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'fee cards show the correct audience and follow settings updates',
    (tester) async {
      final changes = StreamController<BusinessSettings>();
      addTearDown(changes.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessSettingsProvider.overrideWith((ref) => changes.stream),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  PlatformFeeCard(customerType: 'business'),
                  PlatformFeeCard(driver: true),
                ],
              ),
            ),
          ),
        ),
      );
      changes.add(
        BusinessSettings(
          values: {
            'customer_business_fee_bps': 250,
            'customer_individual_fee_bps': 500,
            'driver_platform_fee_bps': 1234,
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2.5%'), findsOneWidget);
      expect(find.text('12.34%'), findsOneWidget);
      changes.add(
        BusinessSettings(
          revision: 1,
          values: {'customer_business_fee_bps': 750},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('7.5%'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      changes.addError(Exception('offline'));
      await tester.pumpAndSettle();
      expect(find.text(PlatformFeeStrings.unavailable), findsNWidgets(2));
    },
  );
}
