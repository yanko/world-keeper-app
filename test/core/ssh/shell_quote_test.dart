import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/core/ssh/shell_quote.dart';

void main() {
  group('shq', () {
    test('wraps a plain value in single quotes', () {
      expect(shq('corekeeper'), "'corekeeper'");
    });

    test('protects spaces — the reference worlds path has them', () {
      expect(
        shq(
          '/home/steam/.config/unity3d/Pugstorm/Core Keeper/DedicatedServer/worlds',
        ),
        "'/home/steam/.config/unity3d/Pugstorm/Core Keeper/DedicatedServer/worlds'",
      );
    });

    test('escapes a single quote by closing, escaping, reopening', () {
      // it's  ->  'it'\''s'
      expect(shq("it's"), r"'it'\''s'");
    });

    test('escapes every single quote, not just the first', () {
      expect(shq("a'b'c"), r"'a'\''b'\''c'");
    });

    test('handles a value that is only quotes', () {
      expect(shq("''"), r"''\'''\'''");
    });

    test('empty string still produces a valid empty shell word', () {
      expect(shq(''), "''");
    });

    test('leaves shell metacharacters inert rather than escaping them', () {
      // Inside single quotes everything is literal, so these need no special handling —
      // that is exactly why single-quoting is the right strategy.
      expect(shq(r'$(rm -rf /)'), r"'$(rm -rf /)'");
      expect(shq('a; b && c | d'), "'a; b && c | d'");
      expect(shq(r'back\slash'), r"'back\slash'");
      expect(shq('new\nline'), "'new\nline'");
    });

    test('quotes the docker --format string that broke when unquoted', () {
      // Real bug from the Rust app: `docker inspect --format {{json .Mounts}}` was sent
      // unquoted, so the shell split it on the space into two argv entries and the
      // mount lookup silently returned nothing.
      expect(shq('{{json .Mounts}}'), "'{{json .Mounts}}'");
    });
  });
}
