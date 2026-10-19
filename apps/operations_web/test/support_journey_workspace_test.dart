import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:latlong2/latlong.dart';
import 'package:operations_web/features/risk_reports/models/risk_journey.dart';
import 'package:operations_web/features/support_monitoring/constants/journey_strings.dart';
import 'package:operations_web/features/support_monitoring/data/journey_archive_repository.dart';
import 'package:operations_web/features/support_monitoring/models/archived_journey_order.dart';
import 'package:operations_web/features/support_monitoring/screens/support_monitoring_screen.dart';
import 'package:operations_web/features/support_monitoring/widgets/journey_playback.dart';
import 'package:operations_web/features/support_orders/models/support_order.dart';

class WorkspaceTiles extends TileProvider {
  @override
  ImageProvider getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) => MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );
}

class WorkspaceRepository implements JourneyArchiveRepository {
  bool fail = false;
  bool mapFail = false;
  bool empty = false;
  final journeyRequests = <String>[];
  final now = DateTime.now().toUtc();
  @override
  Future<List<ArchivedJourneyOrder>> fetchArchives() async {
    if (fail) throw StateError('offline');
    if (empty) return [];
    return [
      for (var i = 1; i <= 3; i++)
        ArchivedJourneyOrder(
          archive: GpsArchive(
            orderId: 'order-$i',
            firstDay: DateTime.utc(
              now.year,
              now.month,
              now.day,
            ).subtract(Duration(days: i == 3 ? 10 : 1)),
            lastDay: DateTime.utc(
              now.year,
              now.month,
              now.day,
            ).subtract(Duration(days: i == 3 ? 10 : 0)),
            chunks: 3,
          ),
          order: RiskOrderSummary(
            id: 'order-$i',
            trackingCode: 'GH-1021$i',
            status: i == 1 ? 'delivered' : 'cancelled',
            pickupAddress: '12 Nguyễn Huệ, Quận 1',
            deliveryAddress: '85 Võ Văn Tần, Quận 3',
            pickupLat: 10.773,
            pickupLng: 106.704,
            deliveryLat: 10.78,
            deliveryLng: 106.69,
          ),
        ),
    ];
  }

  @override
  Future<RiskJourney> fetchJourney(String orderId) async {
    journeyRequests.add(orderId);
    if (mapFail) throw StateError('GPS offline');
    return RiskJourney([
      for (var i = 0; i < 12; i++)
        RiskJourneyPoint(
          LatLng(10.773 + i * .0006, 106.704 - i * .001),
          now.subtract(Duration(minutes: 20 - i)),
          i < 8 ? 'original-driver' : 'replacement-driver',
        ),
    ]);
  }

  @override
  Future<List<SupportOrderStatusLog>> fetchEvents(String orderId) async => [
    SupportOrderStatusLog(
      status: 'delivered',
      title: 'Giao hàng thành công',
      createdAt: now,
    ),
  ];
}

void main() {
  testWidgets(
    'resizing preserves loaded GPS, selected driver, playback and map camera',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = WorkspaceRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: SupportMonitoringScreen(
            repository: repo,
            tileProvider: WorkspaceTiles(),
            onCases: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('journey-order-order-1')));
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .onChanged!('original-driver');
      await tester.pumpAndSettle();
      tester.widget<Slider>(find.byType(Slider)).onChanged!(4);
      final map = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      map.move(const LatLng(10.776, 106.7), 16);
      await tester.pumpAndSettle();
      for (final size in [
        const Size(1280, 850),
        const Size(1000, 800),
        const Size(900, 700),
        const Size(375, 568),
        const Size(1440, 900),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpAndSettle();
        expect(
          repo.journeyRequests,
          ['order-1'],
          reason: 'Resizing to $size must not fetch GPS again',
        );
        expect(
          tester
              .widget<JourneyPlayback>(find.byType(JourneyPlayback))
              .journey
              .points,
          hasLength(8),
        );
        expect(tester.widget<Slider>(find.byType(Slider)).value, 4);
        expect(
          tester
              .widget<FlutterMap>(find.byType(FlutterMap))
              .mapController!
              .camera
              .zoom,
          16,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byTooltip(JourneyStrings.refresh).last);
      await tester.pumpAndSettle();
      expect(repo.journeyRequests, [
        'order-1',
        'order-1',
      ], reason: 'Explicit refresh must fetch fresh GPS');
    },
  );
  for (final viewport in [
    (const Size(1440, 900), 1.0),
    (const Size(375, 568), 1.6),
  ]) {
    testWidgets(
      'browse and replay archive independently of incident at $viewport',
      (tester) async {
        await tester.binding.setSurfaceSize(viewport.$1);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repo = WorkspaceRepository();
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(viewport.$2)),
              child: child!,
            ),
            home: SupportMonitoringScreen(
              repository: repo,
              tileProvider: WorkspaceTiles(),
              onCases: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(repo.journeyRequests, isEmpty);
        Future<void> reveal(Finder finder) async {
          if (finder.evaluate().isEmpty ||
              finder.hitTestable().evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              finder,
              160,
              scrollable: find
                  .descendant(
                    of: find.byKey(const Key('journey-catalog')),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
          }
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
        }

        final card = find.byKey(const ValueKey('journey-order-order-1'));
        await reveal(card);
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(repo.journeyRequests, ['order-1']);
        expect(find.byType(JourneyPlayback), findsOneWidget);
        expect(
          tester
              .widget<JourneyPlayback>(find.byType(JourneyPlayback))
              .journey
              .points,
          hasLength(12),
        );
        // Timeline moves to recorded points; GPS gaps and driver changes stay split.
        final slider = tester.widget<Slider>(find.byType(Slider));
        slider.onChanged!(8);
        await tester.pump();
        expect(tester.widget<Slider>(find.byType(Slider)).value, 8);
        final dropdown = tester.widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        );
        dropdown.onChanged!('original-driver');
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<JourneyPlayback>(find.byType(JourneyPlayback))
              .journey
              .points,
          hasLength(8),
        );
        tester
            .widget<FilledButton>(
              find.byWidgetPredicate((widget) => widget is FilledButton).first,
            )
            .onPressed!();
        await tester.pump(const Duration(milliseconds: 650));
        expect(tester.widget<Slider>(find.byType(Slider)).value, 1);
        tester
            .widget<FilledButton>(
              find.byWidgetPredicate((widget) => widget is FilledButton).first,
            )
            .onPressed!();
        await tester.pump();
        if (viewport.$1.width < 900) {
          await tester.tap(find.byKey(const Key('journey-back')));
          await tester.pumpAndSettle();
        }
        final search = find.byKey(const Key('journey-search'));
        await reveal(search);
        await tester.enterText(search, '10212');
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('journey-order-order-1')),
          findsNothing,
        );
        await reveal(find.byKey(const ValueKey('journey-order-order-2')));
        expect(
          find.byKey(const ValueKey('journey-order-order-2')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'date filter uses archive dates and empty catalog stays distinct',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = WorkspaceRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: SupportMonitoringScreen(
            repository: repo,
            tileProvider: WorkspaceTiles(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(JourneyStrings.results(3)), findsOneWidget);
      await tester.tap(find.text(JourneyStrings.last7));
      await tester.pumpAndSettle();
      expect(find.text(JourneyStrings.results(2)), findsOneWidget);
      expect(find.byKey(const ValueKey('journey-order-order-3')), findsNothing);
      await tester.enterText(
        find.byKey(const Key('journey-search')),
        'không có',
      );
      await tester.pumpAndSettle();
      expect(find.text(JourneyStrings.noResults), findsOneWidget);
      repo.empty = true;
      await tester.tap(find.byTooltip(JourneyStrings.refresh));
      await tester.pumpAndSettle();
      expect(find.text(JourneyStrings.empty), findsOneWidget);
    },
  );
  testWidgets(
    'catalog error retries and map error remains distinct from empty',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = WorkspaceRepository()..fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: SupportMonitoringScreen(
            repository: repo,
            tileProvider: WorkspaceTiles(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(JourneyStrings.loadError), findsOneWidget);
      repo.fail = false;
      repo.mapFail = true;
      await tester.tap(find.text(JourneyStrings.retry));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('journey-order-order-1')));
      await tester.pumpAndSettle();
      expect(find.text(JourneyStrings.mapError), findsOneWidget);
      repo.mapFail = false;
      await tester.tap(find.text(JourneyStrings.retry));
      await tester.pumpAndSettle();
      expect(find.byType(JourneyPlayback), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
