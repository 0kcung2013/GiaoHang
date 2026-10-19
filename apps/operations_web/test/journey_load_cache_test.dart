import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/support_monitoring/data/cached_journey_archive_repository.dart';
import 'support_journey_workspace_test.dart' show WorkspaceRepository;

void main() {
  test(
    'reopening shares loaded/in-flight GPS until explicit refresh',
    () async {
      final source = WorkspaceRepository();
      final cache = CachedJourneyArchiveRepository(source);
      final first = cache.fetchJourney('one');
      expect(identical(first, cache.fetchJourney('one')), isTrue);
      await first;
      await cache.fetchJourney('one');
      expect(source.journeyRequests, ['one']);
      cache.invalidate('one');
      await cache.fetchJourney('one');
      expect(source.journeyRequests, ['one', 'one']);
    },
  );

  test('a failed GPS request can be retried', () async {
    final source = WorkspaceRepository()..mapFail = true;
    final cache = CachedJourneyArchiveRepository(source);
    await expectLater(cache.fetchJourney('one'), throwsStateError);
    source.mapFail = false;
    await cache.fetchJourney('one');
    expect(source.journeyRequests, ['one', 'one']);
  });

  test('recently viewed order cache stays bounded', () async {
    final source = WorkspaceRepository();
    final cache = CachedJourneyArchiveRepository(source, capacity: 2);
    await cache.fetchJourney('one');
    await cache.fetchJourney('two');
    await cache.fetchJourney('one');
    await cache.fetchJourney('three');
    await cache.fetchJourney('two');
    expect(source.journeyRequests, ['one', 'two', 'three', 'two']);
  });
}
