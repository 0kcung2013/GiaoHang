import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:operations_web/features/admin/screens/configuration/business_configuration_screen.dart';
import 'package:operations_web/features/admin/screens/configuration/controllers/business_settings_controller.dart';
import 'package:operations_web/features/admin/screens/configuration/data/business_settings_repository.dart';
import 'package:operations_web/features/admin/screens/configuration/settings_strings.dart';
import 'package:operations_web/features/admin/screens/configuration/models/settings_section.dart';
import 'package:operations_web/features/admin/screens/configuration/widgets/pricing_simulator.dart';
import 'package:operations_web/features/admin/screens/configuration/widgets/pricing_impact_comparison.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'helpers/admin_test_fixtures.dart';

class _Repository implements BusinessSettingsRepository {
  BusinessSettings settings = BusinessSettings();
  bool conflict = false, failHistory = false;
  int writes = 0;
  String? reason;
  @override
  Future<BusinessSettings> load() async => settings;
  @override
  Future<BusinessSettings> save(BusinessSettings value, String reason) async {
    if (conflict) {
      throw const PostgrestException(
        message: 'SETTINGS_CONFLICT',
        code: '40001',
      );
    }
    writes++;
    this.reason = reason;
    return settings = BusinessSettings(
      revision: settings.revision + 1,
      values: value.values,
    );
  }

  @override
  Future<List<SettingsRevision>> history({int? beforeRevision}) async {
    if (failHistory) throw Exception('offline');
    return [
      SettingsRevision.fromJson({
        ...settings.toJson(),
        'previous_values': BusinessSettings.defaults,
        'reason': reason ?? 'Khởi tạo cấu hình',
        'actor_name': 'Admin vận hành',
        'updated_at': '2026-10-26T01:00:00Z',
      }),
    ];
  }
}

class _DelayedRepository extends _Repository {
  Future<BusinessSettings>? loadingResult, savingResult;
  @override
  Future<BusinessSettings> load() => loadingResult ?? super.load();
  @override
  Future<BusinessSettings> save(BusinessSettings value, String reason) =>
      savingResult ?? super.save(value, reason);
}

void main() {
  test('admin edits percentage rates with two decimal places', () async {
    final repo = _Repository();
    final controller = BusinessSettingsController(repo);
    await controller.load();
    controller.edit('customer_individual_fee_bps', '5');
    controller.edit('customer_business_fee_bps', '2,5');
    controller.edit('driver_platform_fee_bps', '12.34');
    controller.reason = 'Cấu hình phí sàn dự kiến';
    expect(await controller.save(), isTrue);
    expect(repo.settings.customerPlatformFeeBps('individual'), 500);
    expect(repo.settings.customerPlatformFeeBps('business'), 250);
    expect(repo.settings.driverPlatformFeeBps, 1234);
    controller.edit('driver_platform_fee_bps', '100.01');
    expect(await controller.save(), isFalse);
    expect(repo.writes, 1);
    controller.dispose();
  });
  setUpAll(() async {
    await loadAdminTestFonts();
    final iconFile = File.fromUri(
      File(
        Platform.resolvedExecutable,
      ).parent.uri.resolve('../../material_fonts/materialicons-regular.otf'),
    );
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(iconFile.readAsBytesSync())));
    await loader.load();
  });

  test(
    'realtime updates clean editors but preserves and blocks an outdated draft',
    () async {
      final updates = StreamController<BusinessSettings>();
      final repo = _Repository();
      final controller = BusinessSettingsController(
        repo,
        updates: updates.stream,
      );
      await controller.load();
      updates.add(BusinessSettings(revision: 1, values: {'base_fee': 20000}));
      await Future<void>.delayed(Duration.zero);
      expect(controller.current!.revision, 1);
      expect(controller.texts['base_fee'], '20.000');
      controller.edit('base_fee', '25.000');
      controller.reason = 'Điều chỉnh giá giao';
      updates.add(BusinessSettings(revision: 2, values: {'base_fee': 22000}));
      await Future<void>.delayed(Duration.zero);
      expect(controller.current!.revision, 1);
      expect(controller.newer!.revision, 2);
      expect(controller.texts['base_fee'], '25.000');
      expect(controller.reason, 'Điều chỉnh giá giao');
      expect(await controller.save(), isFalse);
      expect(repo.writes, 0);
      // Even an older HTTP response cannot overwrite the observed newer version.
      await controller.load();
      expect(controller.current!.revision, 2);
      expect(controller.texts['base_fee'], '22.000');
      expect(controller.newer, isNull);
      controller.dispose();
      expect(updates.hasListener, isFalse);
      await updates.close();
    },
  );

  test(
    'initial fetch cannot overwrite a realtime version received in flight',
    () async {
      final updates = StreamController<BusinessSettings>();
      final loaded = Completer<BusinessSettings>();
      final repo = _DelayedRepository()..loadingResult = loaded.future;
      final controller = BusinessSettingsController(
        repo,
        updates: updates.stream,
      );
      final loading = controller.load();
      updates.add(BusinessSettings(revision: 3));
      await Future<void>.delayed(Duration.zero);
      loaded.complete(BusinessSettings(revision: 1));
      await loading;
      expect(controller.current!.revision, 3);
      controller.dispose();
      await updates.close();
    },
  );

  test(
    'a concurrent update arriving during own save is applied after its response',
    () async {
      final updates = StreamController<BusinessSettings>();
      final saved = Completer<BusinessSettings>();
      final repo = _DelayedRepository()..savingResult = saved.future;
      final controller = BusinessSettingsController(
        repo,
        updates: updates.stream,
      );
      await controller.load();
      controller.edit('base_fee', '25.000');
      controller.reason = 'Điều chỉnh giá giao';
      final saving = controller.save();
      updates.add(BusinessSettings(revision: 2, values: {'base_fee': 27000}));
      await Future<void>.delayed(Duration.zero);
      saved.complete(
        BusinessSettings(revision: 1, values: {'base_fee': 25000}),
      );
      expect(await saving, isTrue);
      expect(controller.current!.revision, 2);
      expect(controller.texts['base_fee'], '27.000');
      controller.dispose();
      await updates.close();
    },
  );

  test(
    'reconnect clears a transient sync error even if revision is unchanged',
    () async {
      final updates = StreamController<BusinessSettings>();
      final controller = BusinessSettingsController(
        _Repository(),
        updates: updates.stream,
      );
      await controller.load();
      updates.addError(StateError('offline'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.syncError, isNotNull);
      updates.add(BusinessSettings());
      await Future<void>.delayed(Duration.zero);
      expect(controller.syncError, isNull);
      controller.dispose();
      await updates.close();
    },
  );

  test(
    'validates linked values and preserves draft on optimistic conflict',
    () async {
      final repo = _Repository();
      final controller = BusinessSettingsController(repo);
      addTearDown(controller.dispose);
      await controller.load();
      controller.edit('auto_radius_m', '4');
      controller.reason = 'Mở rộng vùng phục vụ';
      expect(await controller.save(), isFalse);
      expect(repo.writes, 0);
      controller.edit('free_pick_radius_m', '6');
      repo.conflict = true;
      expect(await controller.save(), isFalse);
      expect(controller.error, SettingsStrings.conflict);
      expect(controller.texts['auto_radius_m'], '4');
      expect(controller.dirty, isTrue);
      expect(controller.current!.revision, 0);
      repo.conflict = false;
      expect(await controller.save(), isTrue);
      expect(repo.writes, 1);
      expect(controller.dirty, isFalse);
      expect(controller.current!.revision, 1);
    },
  );

  test(
    'a history failure does not turn a committed save into a failed save',
    () async {
      final repo = _Repository()..failHistory = true;
      final controller = BusinessSettingsController(repo);
      addTearDown(controller.dispose);
      await controller.load();
      controller.edit('base_fee', '25.000');
      controller.reason = 'Điều chỉnh cước giao';
      expect(await controller.save(), isTrue);
      expect(controller.message, SettingsStrings.saved);
      expect(controller.historyError, SettingsStrings.historyError);
      expect(controller.dirty, isFalse);
    },
  );

  test(
    'restoring old settings keeps retired distance tiers out of the editable draft',
    () async {
      final controller = BusinessSettingsController(_Repository());
      addTearDown(controller.dispose);
      await controller.load();
      controller.restore(
        SettingsRevision.fromJson({
          'revision': 0,
          'values': {...BusinessSettings.legacyDefaults, 'base_fee': 30000},
          'reason': 'Old price list',
          'updated_at': '2026-10-25T00:00:00Z',
        }),
      );
      expect(controller.validValues!.length, 20);
      expect(
        controller.validValues!.containsKey('long_distance_per_km'),
        isFalse,
      );
      expect(controller.draftPricing!.usesLegacyPricing, isFalse);
      expect(controller.message, SettingsStrings.restoreLegacyHint);
    },
  );

  testWidgets(
    'calculator accepts fractional km and updates when draft prices change',
    (tester) async {
      await tester.pumpWidget(
        adminTestApp(PricingSimulator(settings: BusinessSettings())),
      );
      final input = find.byKey(const ValueKey('pricing-distance'));
      await tester.enterText(input, '12');
      await tester.pumpAndSettle();
      expect(find.text('68.000đ'), findsOneWidget);
      expect(find.textContaining('10 km vượt gói'), findsOneWidget);
      await tester.pumpWidget(
        adminTestApp(
          PricingSimulator(
            settings: BusinessSettings(values: {'standard_per_km': 6000}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(input).controller!.text, '12');
      expect(find.text('78.000đ'), findsOneWidget);
      await tester.enterText(input, '2,15');
      await tester.pumpAndSettle();
      expect(find.text('19.000đ'), findsOneWidget);
      await tester.enterText(input, 'abc');
      await tester.pumpAndSettle();
      expect(find.text(SettingsStrings.distanceError), findsOneWidget);
      expect(find.text('19.000đ'), findsNothing);
    },
  );

  for (final width in [320.0, 1440.0]) {
    testWidgets(
      'price comparison distinguishes legacy and new prices at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          adminTestApp(
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: PricingImpactComparison(
                  before: BusinessSettings(
                    values: BusinessSettings.legacyDefaults,
                  ),
                  after: BusinessSettings(),
                ),
              ),
            ),
            scale: width == 320 ? 1.6 : 1,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('98.000đ'), findsOneWidget);
        expect(find.textContaining('108.000đ'), findsOneWidget);
        expect(find.text('Tăng 10.000đ'), findsOneWidget);
        expect(find.text(SettingsStrings.unchanged), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final size in [
    const Size(1440, 900),
    const Size(390, 844),
    const Size(320, 640),
  ]) {
    testWidgets('settings save/preview layout at ${size.width}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repository();
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              primary: AppColors.primary,
              secondary: AppColors.accent,
            ),
            useMaterial3: true,
          ),
          home: Scaffold(
            body: RepaintBoundary(
              key: boundaryKey,
              child: ColoredBox(
                color: AppColors.bgLight,
                child: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(size.width == 320 ? 1.6 : 1),
                  ),
                  child: BusinessConfigurationScreen(repository: repo),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final base = find.byKey(const ValueKey('1-base_fee'));
      expect(tester.widget<TextFormField>(base).initialValue, '18.000');
      await tester.enterText(base, '25000');
      await tester.pumpAndSettle();
      expect(find.text('25.000'), findsOneWidget);
      expect(find.text(SettingsStrings.pendingChanges(1)), findsOneWidget);
      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('settings-content')),
            matching: find.byType(Scrollable),
          )
          .first;
      if (Platform.environment['BUSINESS_SETTINGS_SCREENSHOT'] == '1') {
        FocusManager.instance.primaryFocus?.unfocus();
        tester.state<ScrollableState>(scrollable).position.jumpTo(0);
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final rendered = await boundary.toImage();
          final bytes = await rendered.toByteData(
            format: ui.ImageByteFormat.png,
          );
          final file = File('.tmp/business-settings-${size.width.toInt()}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          rendered.dispose();
        });
      }
      await _selectSection(tester, SettingsSection.contact);
      expect(find.byKey(const ValueKey('1-base_fee')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('1-company_name')),
        'Đơn vị thử nghiệm',
      );
      await tester.pumpAndSettle();
      await _selectSection(tester, SettingsSection.wallet);
      await tester.enterText(
        find.byKey(const ValueKey('1-topup_min')),
        '30000',
      );
      await tester.pumpAndSettle();
      await _selectSection(tester, SettingsSection.pricing);
      expect(tester.widget<TextFormField>(base).initialValue, '25.000');
      expect(find.text(SettingsStrings.pendingChanges(3)), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('settings-primary-action')));
      await tester.pumpAndSettle();
      expect(find.text(SettingsStrings.reviewHint), findsOneWidget);
      await _revealIn(
        tester,
        scrollable,
        find.byKey(const ValueKey('reason-1')),
      );
      if (Platform.environment['BUSINESS_SETTINGS_SCREENSHOT'] == '1') {
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final rendered = await boundary.toImage();
          final bytes = await rendered.toByteData(
            format: ui.ImageByteFormat.png,
          );
          await File(
            '.tmp/business-settings-review-${size.width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          rendered.dispose();
        });
      }
      await tester.enterText(
        find.byKey(const ValueKey('reason-1')),
        'Thay đổi bảng giá',
      );
      await _selectSection(tester, SettingsSection.contact);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('1-company_name')))
            .initialValue,
        'Đơn vị thử nghiệm',
      );
      await tester.tap(find.byKey(const ValueKey('settings-primary-action')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('reason-1')))
            .initialValue,
        'Thay đổi bảng giá',
      );
      await tester.tap(find.byKey(const ValueKey('settings-primary-action')));
      await tester.pumpAndSettle();
      expect(repo.writes, 1);
      expect(repo.settings.number('base_fee'), 25000);
      expect(repo.settings.topupMin, 30000);
      expect(repo.settings.companyName, 'Đơn vị thử nghiệm');
      expect(repo.settings.number('standard_per_km'), 5000);
      expect(repo.settings.values.length, 20);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'review points to invalid fields in a section that is no longer open',
    (tester) async {
      final repo = _Repository();
      await tester.pumpWidget(
        adminTestApp(BusinessConfigurationScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('1-base_fee')), '0');
      await _selectSection(tester, SettingsSection.contact);
      await tester.tap(find.byKey(const ValueKey('settings-primary-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-primary-action')));
      await tester.pumpAndSettle();
      expect(repo.writes, 0);
      final invalid = find.text('Giá cước & hoàn hàng: Phí cơ bản');
      await _revealIn(tester, _contentScrollable(), invalid);
      await tester.tap(invalid);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('1-base_fee')), findsOneWidget);
      expect(find.textContaining('Nhập từ 5.000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _selectSection(
  WidgetTester tester,
  SettingsSection section,
) async {
  final desktopItem = find.byKey(ValueKey('settings-section-${section.name}'));
  if (desktopItem.evaluate().isNotEmpty) {
    await tester.tap(desktopItem);
  } else {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    tester.state<ScrollableState>(_contentScrollable()).position.jumpTo(0);
    await tester.pumpAndSettle();
    final picker = find.byKey(const ValueKey('settings-section-picker'));
    await tester.tap(picker);
    await tester.pumpAndSettle();
    final item = find.text(section.label).last;
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    await tester.tap(item);
  }
  await tester.pumpAndSettle();
}

Finder _contentScrollable() => find
    .descendant(
      of: find.byKey(const ValueKey('settings-content')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _revealIn(
  WidgetTester tester,
  Finder scrollable,
  Finder target,
) async {
  await tester
      .state<ScrollableState>(scrollable)
      .position
      .ensureVisible(tester.renderObject(target));
  await tester.pumpAndSettle();
}
