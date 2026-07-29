import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/app/providers.dart';
import 'package:world_keeper/app/theme.dart';
import 'package:world_keeper/core/audit/audit_database.dart';
import 'package:world_keeper/core/audit/audit_database_factory.dart';
import 'package:world_keeper/core/config/app_paths.dart';
import 'package:world_keeper/core/config/models.dart';
import 'package:world_keeper/core/target/service_kind.dart';
import 'package:world_keeper/features/discovery/domain/discovery_result.dart';
import 'package:world_keeper/features/discovery/presentation/discovery_screen.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// Both halves of "the screen has to say what happened".
///
/// The Confirm button wrote the discovery, unlocked five other screens, and showed
/// nothing — the only visible change was an 8px dot in the app bar going from red to
/// teal. And a failed probe said "none found" with no indication of where it had looked.
/// Neither was a broken code path; both were the app declining to talk.
void main() {
  late Directory tempDir;
  late AuditDatabase db;
  late int sessionId;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wk_discovery_test');
    db = AuditDatabaseFactory.inMemory();
    sessionId = await db.startSession('test');
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPathsProvider.overrideWithValue(AppPaths.forTesting(tempDir)),
          auditDatabaseProvider.overrideWithValue(db),
          initialAuditSessionIdProvider.overrideWithValue(sessionId),
        ],
        child: MaterialApp(
          theme: WkTheme.dark(),
          localizationsDelegates: localizationsDelegates,
          supportedLocales: supportedLocales,
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump();
  }

  group('the transcript panel', () {
    const trace = [
      ProbeStep(
        command: 'cat /etc/os-release 2>/dev/null',
        exitStatus: 0,
        stdout: 'PRETTY_NAME="Debian GNU/Linux 13 (trixie)"',
        stderr: '',
        duration: Duration(milliseconds: 8),
      ),
      ProbeStep(
        command: "find '/home' -name '*.world.gzip' 2>/dev/null",
        exitStatus: 0,
        stdout: '',
        stderr: '',
        duration: Duration(milliseconds: 120),
      ),
    ];

    testWidgets('is collapsed until asked for', (tester) async {
      // On a host where discovery works nobody needs this, and unfolding twelve commands
      // by default would bury the answer under the working.
      await pump(tester, const ProbeTranscript(trace: trace));

      expect(find.text('What the probe did'), findsOneWidget);
      expect(find.textContaining('/etc/os-release'), findsNothing);
    });

    testWidgets('shows every command and its output when opened', (
      tester,
    ) async {
      await pump(tester, const ProbeTranscript(trace: trace));

      await tester.tap(find.text('What the probe did'));
      await tester.pumpAndSettle();

      expect(find.textContaining('/etc/os-release'), findsOneWidget);
      expect(find.textContaining('trixie'), findsOneWidget);
      expect(find.textContaining("find '/home'"), findsOneWidget);
      // The empty `find` is the interesting one: it ran, and found nothing.
      expect(find.text('no output'), findsOneWidget);
    });

    testWidgets('says how many commands ran', (tester) async {
      await pump(tester, const ProbeTranscript(trace: trace));
      expect(find.text('2 commands, all ran'), findsOneWidget);
    });

    testWidgets('a command that could not run is not reported as "none found"', (
      tester,
    ) async {
      // The distinction the whole panel exists for. A `find` that exits 127 means the
      // probe is broken; the old screen showed exactly the same "none found" either way.
      await pump(
        tester,
        const ProbeTranscript(
          trace: [
            ProbeStep(
              command: 'find / -name worlds',
              exitStatus: 127,
              stdout: '',
              stderr: 'sh: find: not found',
              duration: Duration.zero,
            ),
          ],
        ),
      );

      expect(find.text('1 command, 1 could not run'), findsOneWidget);

      await tester.tap(find.text('What the probe did'));
      await tester.pumpAndSettle();
      expect(find.textContaining('find: not found'), findsOneWidget);
      expect(find.text('exit 127'), findsOneWidget);
    });

    testWidgets('renders nothing at all when there is no trace', (
      tester,
    ) async {
      await pump(tester, const ProbeTranscript(trace: []));
      expect(find.text('What the probe did'), findsNothing);
    });
  });

  group('the confirmed panel', () {
    const discovered = Discovered(
      os: 'Debian GNU/Linux 13 (trixie)',
      serviceKind: SystemdService(unit: 'corekeeper.service'),
      worldsPath: '/home/steam/Core Keeper/worlds',
      steamUser: 'steam',
      probedAt: '2026-07-28T20:15:00Z',
    );

    testWidgets('names the three values it saved', (tester) async {
      // Not just "Saved": the point of confirming is that these exact strings are what
      // every later push and restore will operate on, so they are worth reading back.
      await pump(
        tester,
        ConfirmedPanel(discovered: discovered, onChange: () {}),
      );

      expect(find.text('Confirmed — this server is ready'), findsOneWidget);
      expect(find.text('systemd: corekeeper.service'), findsOneWidget);
      expect(find.text('/home/steam/Core Keeper/worlds'), findsOneWidget);
      expect(find.text('steam'), findsOneWidget);
    });

    testWidgets('says what confirming unlocked', (tester) async {
      await pump(
        tester,
        ConfirmedPanel(discovered: discovered, onChange: () {}),
      );

      expect(find.textContaining('Push'), findsOneWidget);
    });

    testWidgets('offers a way back', (tester) async {
      var changed = false;
      await pump(
        tester,
        ConfirmedPanel(discovered: discovered, onChange: () => changed = true),
      );

      await tester.tap(find.text('Change'));
      expect(changed, isTrue);
    });

    testWidgets('omits the user when the probe never found one', (
      tester,
    ) async {
      // A bare-process target usually has one; a Docker one never does. An empty row
      // labelled "Runs as" reads as a failure rather than as not-applicable.
      await pump(
        tester,
        ConfirmedPanel(
          discovered: const Discovered(
            serviceKind: DockerService(container: 'core-keeper'),
            worldsPath: '/srv/worlds',
            probedAt: '2026-07-28T20:15:00Z',
          ),
          onChange: () {},
        ),
      );

      expect(find.text('Runs as'), findsNothing);
      expect(find.text('/srv/worlds'), findsOneWidget);
    });
  });
}
