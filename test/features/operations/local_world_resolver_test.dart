import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:world_keeper/core/errors/exceptions.dart';
import 'package:world_keeper/features/operations/data/local_world_resolver.dart';

void main() {
  const resolver = LocalWorldResolver();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wk_local_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<File> write(String relativePath, [List<int>? bytes]) async {
    final file = File(p.join(tempDir.path, relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes ?? const [1, 2, 3, 4]);
    return file;
  }

  group('folders', () {
    test('finds a world and its pugbackup', () async {
      await write('0.world.gzip', List.filled(100, 7));
      await write('0.world.gzip.pugbackup', List.filled(50, 8));

      final found = await resolver.resolve(tempDir.path);

      expect(found, hasLength(1));
      expect(found.single.slot, 0);
      expect(found.single.slotInferred, isTrue);
      expect(found.single.mainSize, 100);
      expect(found.single.pugbackupSize, 50);
      expect(found.single.hasPugbackup, isTrue);
      expect(found.single.mainModified, isNotNull);
    });

    test('groups several slots and sorts them', () async {
      await write('2.world.gzip');
      await write('0.world.gzip');
      await write('10.world.gzip');

      final found = await resolver.resolve(tempDir.path);
      expect(found.map((c) => c.slot), [0, 2, 10]);
    });

    test('searches recursively', () async {
      await write(p.join('backup', 'nested', '5.world.gzip'));
      final found = await resolver.resolve(tempDir.path);
      expect(found.single.slot, 5);
    });

    test('ignores files that share the prefix but are not the world', () async {
      // `.old`, `.backup`, and hand-made copies are not worlds, however similar they
      // look. Accepting them would let a stale snapshot be pushed as the real thing.
      await write('0.world.gzip');
      await write('0.world.gzip.old');
      await write('0.world.gzip.old2');
      await write('0.world.gzip.backup');
      await write('0.world.gzip.manual-2026-07-26');

      final found = await resolver.resolve(tempDir.path);
      expect(found, hasLength(1));
      expect(found.single.hasPugbackup, isFalse);
    });

    test('a folder with nothing recognisable explains itself', () async {
      await write('readme.txt');
      await expectLater(
        resolver.resolve(tempDir.path),
        throwsA(
          isA<LocalWorldException>().having(
            (e) => e.message,
            'message',
            contains('no *.world.gzip files found'),
          ),
        ),
      );
    });

    test('a pugbackup with no main file yields nothing', () async {
      // Half a world is not a world.
      await write('0.world.gzip.pugbackup');
      await expectLater(
        resolver.resolve(tempDir.path),
        throwsA(isA<LocalWorldException>()),
      );
    });
  });

  group('a single file', () {
    test('picking a strictly-named world scans its whole folder', () async {
      // So the sibling pugbackup comes along, exactly as choosing the folder would.
      final main = await write('0.world.gzip');
      await write('0.world.gzip.pugbackup');

      final found = await resolver.resolve(main.path);
      expect(found.single.hasPugbackup, isTrue);
    });

    test('picking one world in a folder of several offers them all', () async {
      final main = await write('0.world.gzip');
      await write('1.world.gzip');

      final found = await resolver.resolve(main.path);
      expect(found.map((c) => c.slot), [0, 1]);
    });

    test('accepts a loosely-named file with no inferable slot', () async {
      // A manual export, a file someone shared, something renamed along the way. This is
      // also how a brand-new slot gets seeded from an arbitrary file.
      final odd = await write('my cool world.world.gzip', List.filled(42, 1));

      final found = await resolver.resolve(odd.path);
      expect(found, hasLength(1));
      expect(found.single.slotInferred, isFalse);
      expect(
        found.single.slot,
        0,
        reason: 'defaults to 0 for the UI to override',
      );
      expect(found.single.mainSize, 42);
      expect(found.single.mainPath, odd.path);
    });

    test('a loose match takes only that file, not its neighbours', () async {
      await write('0.world.gzip');
      final odd = await write('renamed.world.gzip');

      final found = await resolver.resolve(odd.path);
      expect(found, hasLength(1));
      expect(found.single.mainPath, odd.path);
    });

    test('matches the extension case-insensitively', () async {
      final odd = await write('Export.WORLD.GZIP');
      final found = await resolver.resolve(odd.path);
      expect(found.single.slotInferred, isFalse);
    });

    test('rejects an unrelated file', () async {
      final other = await write('notes.txt');
      await expectLater(
        resolver.resolve(other.path),
        throwsA(
          isA<LocalWorldException>().having(
            (e) => e.message,
            'message',
            contains('not a folder, a .zip, or a .world.gzip file'),
          ),
        ),
      );
    });

    test('rejects a path that does not exist', () async {
      await expectLater(
        resolver.resolve(p.join(tempDir.path, 'ghost.world.gzip')),
        throwsA(isA<LocalWorldException>()),
      );
    });

    test('accepts a file with no content validation at all', () async {
      // Deliberate: despite the extension these files are NOT gzip — `gzip -t` rejects a
      // real one and the magic bytes are not 1F 8B. An earlier magic-byte check rejected
      // every genuine world file. There is no signature to test, so the name is the only
      // available signal.
      final notGzip = await write(
        '0.world.gzip',
        'plain text, definitely not gzip'.codeUnits,
      );
      final found = await resolver.resolve(notGzip.path);
      expect(found, hasLength(1));
    });
  });

  group('zips', () {
    Future<File> zipContaining(Map<String, List<int>> entries) async {
      final staging = Directory(p.join(tempDir.path, 'staging'))
        ..createSync(recursive: true);
      for (final entry in entries.entries) {
        final f = File(p.join(staging.path, entry.key));
        await f.parent.create(recursive: true);
        await f.writeAsBytes(entry.value);
      }

      final zipPath = p.join(tempDir.path, 'world.zip');
      final encoder = ZipFileEncoder()..create(zipPath);
      await encoder.addDirectory(staging, includeDirName: false);
      await encoder.close();

      await staging.delete(recursive: true);
      return File(zipPath);
    }

    test('extracts and finds the world inside', () async {
      final zip = await zipContaining({
        '0.world.gzip': List.filled(64, 3),
        '0.world.gzip.pugbackup': List.filled(32, 4),
      });

      final found = await resolver.resolve(zip.path);

      expect(found, hasLength(1));
      expect(found.single.slot, 0);
      expect(found.single.hasPugbackup, isTrue);
      // The extracted copy is what gets pushed, so the archive itself is untouched.
      expect(found.single.mainPath, isNot(contains('.zip')));
      expect(zip.existsSync(), isTrue);
    });

    test('finds worlds nested inside the archive', () async {
      final zip = await zipContaining({
        p.join('saves', 'backup', '3.world.gzip'): const [1],
      });
      final found = await resolver.resolve(zip.path);
      expect(found.single.slot, 3);
    });

    test('a zip with no worlds explains itself', () async {
      final zip = await zipContaining({'readme.txt': 'hello'.codeUnits});
      await expectLater(
        resolver.resolve(zip.path),
        throwsA(isA<LocalWorldException>()),
      );
    });

    test(
      'a corrupt zip fails with a clear message rather than a crash',
      () async {
        final broken = await write('broken.zip', 'this is not a zip'.codeUnits);
        await expectLater(
          resolver.resolve(broken.path),
          throwsA(
            isA<LocalWorldException>().having(
              (e) => e.message,
              'message',
              contains('could not read the zip'),
            ),
          ),
        );
      },
    );

    test('matches the .zip extension case-insensitively', () async {
      final zip = await zipContaining({
        '0.world.gzip': const [1],
      });
      final upper = File(p.join(tempDir.path, 'WORLD.ZIP'));
      await zip.copy(upper.path);

      final found = await resolver.resolve(upper.path);
      expect(found.single.slot, 0);
    });
  });

  group('LocalWorldCandidate', () {
    test('withSlot retargets without losing anything else', () async {
      final odd = await write('export.world.gzip');
      final candidate = (await resolver.resolve(odd.path)).single;

      final retargeted = candidate.withSlot(4);
      expect(retargeted.slot, 4);
      expect(retargeted.mainPath, candidate.mainPath);
      expect(retargeted.mainSize, candidate.mainSize);
      expect(retargeted.slotInferred, isFalse);
    });
  });
}
