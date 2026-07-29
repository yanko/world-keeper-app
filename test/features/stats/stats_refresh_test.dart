import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/audit/audit_database_factory.dart';
import 'package:world_keeper/core/config/app_paths.dart';
import 'package:world_keeper/features/stats/domain/server_stats.dart';
import 'package:world_keeper/features/stats/presentation/stats_screen.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// Two ways to ask for fresh numbers, because they are for different hands.
///
/// Pull-to-refresh is what a phone user reaches for and is invisible to a mouse; a button
/// is the reverse. Neither is redundant on the device the other was built for, so both
/// exist and both are checked.
void main() {
  late Directory tempDir;
  late AuditDatabase db;
  late int sessionId;

  const stats = ServerStats(
    serviceStatus: 'active',
    memTotalKb: 8000000,
    memAvailableKb: 6000000,
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wk_stats_test');
    db = AuditDatabaseFactory.inMemory();
    sessionId = await db.startSession('test');
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester, {required Size size}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPathsProvider.overrideWithValue(AppPaths.forTesting(tempDir)),
          auditDatabaseProvider.overrideWithValue(db),
          initialAuditSessionIdProvider.overrideWithValue(sessionId),
          // A fixed reading, so the widgets under test are not racing a poll loop.
          statsProvider.overrideWith((ref) => Stream.value(stats)),
        ],
        child: MaterialApp(
          theme: WkTheme.dark(),
          localizationsDelegates: localizationsDelegates,
          supportedLocales: supportedLocales,
          home: const StatsScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a refresh button is there for a mouse', (tester) async {
    await pump(tester, size: const Size(1440, 900));
    expect(find.byTooltip('Refresh now'), findsOneWidget);
  });

  testWidgets('and on a phone too, beside the pull gesture', (tester) async {
    await pump(tester, size: const Size(360, 800));
    expect(find.byTooltip('Refresh now'), findsOneWidget);
  });

  testWidgets('the list is pullable even when the content fits', (
    tester,
  ) async {
    // Without `AlwaysScrollableScrollPhysics` the gesture does nothing whenever the
    // readings happen to fit the screen, which is most of the time on a tall phone — so
    // pull-to-refresh would appear to work only sometimes, which is worse than not at all.
    await pump(tester, size: const Size(360, 900));

    expect(find.byType(RefreshIndicator), findsOneWidget);

    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.physics, isA<AlwaysScrollableScrollPhysics>());
  });

  testWidgets('pulling down runs a refresh', (tester) async {
    await pump(tester, size: const Size(360, 800));

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pump();

    // The indicator being on screen is the gesture having been accepted; the collection
    // itself is the provider's job and is overridden here.
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('a refresh does not blank the readings it is refreshing', (
    tester,
  ) async {
    // Riverpod reports a re-fetch as loading *with* the previous value attached. Rendering
    // the spinner then would replace a screenful of numbers with an empty box every time a
    // manual refresh overlapped a poll.
    await pump(tester, size: const Size(1440, 900));
    expect(find.text('active'), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh now'));
    await tester.pump();

    expect(
      find.text('active'),
      findsOneWidget,
      reason: 'the last good reading stays up while the next one is fetched',
    );
  });
}
