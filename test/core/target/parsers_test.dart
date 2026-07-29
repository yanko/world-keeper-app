import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/core/target/exec_output.dart';
import 'package:world_keeper/core/target/parsers.dart';

void main() {
  group('parseFindPrintf', () {
    test('parses size, mtime and path', () {
      final entries = parseFindPrintf(
        '5046105 1753564800.0000000000 /home/steam/worlds/0.world.gzip\n',
      );
      expect(entries, hasLength(1));
      expect(entries.single.size, 5046105);
      expect(entries.single.modified, 1753564800);
      expect(entries.single.path, '/home/steam/worlds/0.world.gzip');
      expect(entries.single.name, '0.world.gzip');
    });

    test('keeps paths containing spaces intact', () {
      // The reference worlds path is
      // `…/Pugstorm/Core Keeper/DedicatedServer/worlds` — a whitespace split truncates
      // every real path at "Core", so this is the case that actually matters.
      const path =
          '/home/steam/.config/unity3d/Pugstorm/Core Keeper/DedicatedServer/worlds/0.world.gzip';
      final entries = parseFindPrintf('5046105 1753564800.0000000000 $path\n');
      expect(entries.single.path, path);
      expect(entries.single.name, '0.world.gzip');
    });

    test('parses multiple lines and ignores blanks', () {
      final entries = parseFindPrintf('''
5046105 1753564800.0000000000 /w/0.world.gzip

5047192 1753564700.5000000000 /w/0.world.gzip.pugbackup
''');
      expect(entries.map((e) => e.name), [
        '0.world.gzip',
        '0.world.gzip.pugbackup',
      ]);
      // Fractional seconds truncate rather than round.
      expect(entries[1].modified, 1753564700);
    });

    test('returns empty for empty output', () {
      expect(parseFindPrintf(''), isEmpty);
      expect(parseFindPrintf('\n\n'), isEmpty);
    });

    test('skips malformed lines instead of throwing', () {
      // Remote output is not trustworthy; one bad line must not lose the good ones.
      final entries = parseFindPrintf('''
garbage
123 /no/mtime/field
5046105 1753564800.0 /w/0.world.gzip
''');
      expect(entries, hasLength(1));
      expect(entries.single.name, '0.world.gzip');
    });

    test('tolerates a non-numeric mtime by reporting null', () {
      final entries = parseFindPrintf('100 notanumber /w/x\n');
      expect(entries.single.modified, isNull);
      expect(entries.single.size, 100);
    });
  });

  group('parseStatLines (POSIX fallback)', () {
    test('parses `stat -c %s %Y %n` output', () {
      final entries = parseStatLines('5046105 1753564800 /w/0.world.gzip\n');
      expect(entries.single.size, 5046105);
      expect(entries.single.modified, 1753564800);
      expect(entries.single.path, '/w/0.world.gzip');
    });

    test('also survives spaces in paths', () {
      final entries = parseStatLines(
        '12 1753564800 /w/Core Keeper/0.world.gzip\n',
      );
      expect(entries.single.path, '/w/Core Keeper/0.world.gzip');
    });
  });

  group('findGameId', () {
    test('finds the reference LXC format', () {
      expect(
        findGameId('Jul 26 12:00:00 ck[123]: GameID: ABCD-1234'),
        'ABCD-1234',
      );
    });

    test('finds the second known Docker format', () {
      expect(findGameId('Started session with info: XYZ-9876'), 'XYZ-9876');
    });

    test("finds ich777's wrapper format", () {
      expect(findGameId('[INFO] Server Game ID: QQQ-0001'), 'QQQ-0001');
    });

    test('takes the LAST match, so a restart beats a stale line', () {
      // The whole reason for scanning in reverse: after a swap the previous world's id
      // is still sitting in the same tail window, and reporting it would name the world
      // that was just replaced.
      const log = '''
GameID: OLD-0000
… server restarting …
GameID: NEW-1111
''';
      expect(findGameId(log), 'NEW-1111');
    });

    test('does not match "GameID path:"', () {
      // The marker requires the colon immediately after GameID, so this related-but-
      // different line cannot shadow the real one.
      expect(findGameId('GameID path: /home/steam/gameid.txt'), isNull);
    });

    test('still finds a real id on a later line than a GameID path line', () {
      const log = '''
GameID path: /home/steam/gameid.txt
GameID: REAL-2222
''';
      expect(findGameId(log), 'REAL-2222');
    });

    test('ignores a marker with nothing after it', () {
      expect(findGameId('GameID:   '), isNull);
    });

    test('returns null for logs with no marker', () {
      expect(findGameId('nothing to see here'), isNull);
      expect(findGameId(''), isNull);
    });

    test('trims surrounding whitespace and carriage returns', () {
      expect(findGameId('GameID:   PADDED-3333  '), 'PADDED-3333');
    });
  });

  group('parseWorldFilename', () {
    test('recognises the main world file', () {
      final r = parseWorldFilename('0.world.gzip');
      expect(r!.slot, 0);
      expect(r.isPugbackup, isFalse);
    });

    test('recognises the pugbackup sibling', () {
      final r = parseWorldFilename('3.world.gzip.pugbackup');
      expect(r!.slot, 3);
      expect(r.isPugbackup, isTrue);
    });

    test('handles multi-digit slots', () {
      expect(parseWorldFilename('12.world.gzip')!.slot, 12);
    });

    test('rejects the extra snapshots that share the prefix', () {
      // ich777's image keeps .old/.old2/.backup alongside the real files, and users
      // make their own copies. Sweeping these into a backup — or restoring over one —
      // was a real footgun.
      expect(parseWorldFilename('0.world.gzip.old'), isNull);
      expect(parseWorldFilename('0.world.gzip.old2'), isNull);
      expect(parseWorldFilename('0.world.gzip.backup'), isNull);
      expect(parseWorldFilename('0.world.gzip.manual-2026-07-26'), isNull);
    });

    test('rejects names without a numeric slot', () {
      expect(parseWorldFilename('world.gzip'), isNull);
      expect(parseWorldFilename('.world.gzip'), isNull);
      expect(parseWorldFilename('backup.world.gzip'), isNull);
      expect(parseWorldFilename('my0.world.gzip'), isNull);
      expect(parseWorldFilename('-1.world.gzip'), isNull);
      expect(parseWorldFilename(' 0.world.gzip'), isNull);
    });

    test('rejects unrelated names', () {
      expect(parseWorldFilename('readme.txt'), isNull);
      expect(parseWorldFilename(''), isNull);
    });
  });

  group('parseMeminfo', () {
    const sample = '''
MemTotal:        8039424 kB
MemFree:          204816 kB
MemAvailable:    6100992 kB
Buffers:          131072 kB
''';

    test('reads total and available', () {
      final r = parseMeminfo(sample);
      expect(r.totalKb, 8039424);
      expect(r.availableKb, 6100992);
    });

    test('ignores MemFree, which reads alarmingly low on a healthy host', () {
      expect(parseMeminfo(sample).availableKb, isNot(204816));
    });

    test('returns nulls when the fields are absent', () {
      final r = parseMeminfo('something else entirely');
      expect(r.totalKb, isNull);
      expect(r.availableKb, isNull);
    });

    test('does not confuse MemTotal with a prefix match', () {
      // `MemTotalSomething:` must not be read as MemTotal.
      final r = parseMeminfo('MemAvailable: 42 kB\n');
      expect(r.availableKb, 42);
      expect(r.totalKb, isNull);
    });
  });

  group('parseDf', () {
    test('parses the four columns', () {
      final r = parseDf('  9.8G  4.1G  5.2G  44%');
      expect(r.size, '9.8G');
      expect(r.used, '4.1G');
      expect(r.avail, '5.2G');
      expect(r.usePct, '44%');
    });

    test('returns nulls for missing columns rather than throwing', () {
      final r = parseDf('9.8G');
      expect(r.size, '9.8G');
      expect(r.used, isNull);
      expect(r.usePct, isNull);
    });

    test('handles empty input', () {
      expect(parseDf('').size, isNull);
    });
  });

  group('parseDockerUdpPorts', () {
    test('extracts the host port after the arrow', () {
      expect(parseDockerUdpPorts('27015/udp -> 0.0.0.0:27015\n'), ['27015']);
    });

    test('uses the LAST colon so IPv6 bindings work', () {
      // `[::]:27015` — splitting on the first colon yields nothing useful.
      expect(parseDockerUdpPorts('27015/udp -> [::]:27015\n'), ['27015']);
    });

    test('collects several ports and de-duplicates', () {
      const out = '''
27015/udp -> 0.0.0.0:27015
27015/udp -> [::]:27015
27016/udp -> 0.0.0.0:27016
''';
      expect(parseDockerUdpPorts(out), ['27015', '27016']);
    });

    test('ignores lines with no mapping', () {
      expect(parseDockerUdpPorts('nothing here\n'), isEmpty);
      expect(parseDockerUdpPorts(''), isEmpty);
    });
  });

  group('status parsers', () {
    test('map systemd vocabulary', () {
      expect(parseSystemdStatus('active\n'), RunState.running);
      expect(parseSystemdStatus('inactive\n'), RunState.stopped);
      expect(parseSystemdStatus('failed\n'), RunState.failed);
      expect(parseSystemdStatus('activating\n'), RunState.unknown);
      expect(parseSystemdStatus(''), RunState.unknown);
    });

    test('map docker vocabulary', () {
      expect(parseDockerStatus('running\n'), RunState.running);
      for (final stopped in ['exited', 'created', 'dead', 'paused']) {
        expect(parseDockerStatus('$stopped\n'), RunState.stopped);
      }
    });

    test('treat a restarting container as unknown, not running', () {
      // A crash-looping container reports `restarting`. Calling that "up" would let the
      // envelope declare a start successful moments before the next crash.
      expect(parseDockerStatus('restarting\n'), RunState.unknown);
    });
  });

  group('parseProcNetUdp', () {
    test('drops the header and blank lines', () {
      const out = '''
  sl  local_address rem_address   st tx_queue rx_queue
  0: 00000000:DE47 00000000:0000 07 00000000:00000000

  1: 00000000:0044 00000000:0000 07 00000000:00000000
''';
      final lines = parseProcNetUdp(out);
      expect(lines, hasLength(2));
      expect(lines.every((l) => !l.contains('local_address')), isTrue);
    });

    test('returns empty when nothing is bound', () {
      expect(
        parseProcNetUdp('  sl  local_address rem_address   st\n'),
        isEmpty,
      );
    });
  });
}
