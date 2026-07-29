import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/core/config/app_paths.dart';

/// The installer cannot be exercised from a Dart test — compiling it needs Inno Setup and
/// running it needs a machine you are willing to install onto. What is checkable here is
/// the small set of things that are wrong *silently*: an installer that compiles, runs,
/// looks correct, and has quietly done something it should not have.
void main() {
  final root = Directory.current;
  File file(String relative) => File('${root.path}/$relative');

  late String iss;

  setUpAll(() {
    iss = file('installer/windows/world_keeper.iss').readAsStringSync();
  });

  test('the uninstaller deletes nothing outside its own directory', () {
    // `%APPDATA%\com.civortech.worldkeeper` holds config.json, the generated SSH keys and
    // the audit log — and it is *shared with the Tauri build*, which is the entire reason
    // AppPaths reproduces Tauri's path resolution instead of using path_provider. An
    // [UninstallDelete] entry pointing there would wipe the other app's setup as a side
    // effect of removing this one, and take the record of every operation ever run
    // against a live server with it.
    expect(
      _section(iss, 'UninstallDelete'),
      isEmpty,
      reason:
          'the uninstaller must not remove ${AppPaths.tauriIdentifier}; that directory '
          'belongs to both builds of the app',
    );

    // And nowhere else either — [InstallDelete] and a `Filename: cmd.exe` [Run] entry
    // reach just as far. Comments are exempt: the section above explains at length why
    // the path is left alone, and naming it there is the point.
    final executable = iss
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith(';'));

    expect(
      executable.where((line) => line.contains(AppPaths.tauriIdentifier)),
      isEmpty,
      reason: 'an instruction in the installer names the shared data directory',
    );
  });

  test('the upgrade identity is a real, fixed GUID', () {
    // Windows matches an upgrade against AppId. Regenerate it and the next version
    // installs beside this one, leaving two entries in Apps & Features and two copies on
    // disk, with the old one still on the Start menu.
    final match = RegExp(
      r'^AppId=\{\{([0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12})',
      multiLine: true,
    ).firstMatch(iss);

    expect(
      match,
      isNotNull,
      reason: 'AppId is missing or is not a literal GUID',
    );
  });

  test('it installs the executable CMake actually produces', () {
    final binaryName = RegExp(
      r'set\(BINARY_NAME "([^"]+)"\)',
    ).firstMatch(file('windows/CMakeLists.txt').readAsStringSync())!.group(1);

    expect(iss, contains('#define AppExeName "$binaryName.exe"'));
  });

  test('the Windows version resource names the app, not the package', () {
    // Task Manager, the file properties sheet and the SmartScreen prompt all read these.
    // The Flutter template fills them from the pubspec `name:`, which is `world_keeper`.
    final rc = file('windows/runner/Runner.rc').readAsStringSync();

    expect(rc, contains('VALUE "ProductName", "World Keeper"'));
    expect(rc, contains('VALUE "FileDescription", "World Keeper"'));
    expect(
      rc,
      isNot(contains('VALUE "ProductName", "world_keeper"')),
      reason: 'still the template default',
    );
  });

  group('build.ps1', () {
    late File script;

    setUpAll(() => script = file('installer/windows/build.ps1'));

    test('is pure ASCII and starts with a UTF-8 BOM', () {
      // `powershell -File` is Windows PowerShell 5.1, which decodes a BOM-less script
      // with the ANSI code page — and PowerShell's tokenizer accepts the smart quotes at
      // 0x91-0x94 as string delimiters. So a UTF-8 em dash inside a double-quoted string
      // arrives as three bytes whose last one *closes the string*, every string after it
      // shifts by one, and the script fails somewhere with no relation to the character.
      // Both halves of the guard are here because either one alone would have caught it.
      final bytes = script.readAsBytesSync();

      expect(bytes.take(3), [
        0xEF,
        0xBB,
        0xBF,
      ], reason: 'no UTF-8 BOM: 5.1 will decode this as ANSI');
      expect(
        bytes.skip(3).where((b) => b > 0x7F),
        isEmpty,
        reason:
            'non-ASCII byte in a script Windows PowerShell 5.1 has to parse',
      );
    });

    test('passes the version through rather than holding its own copy', () {
      final source = script.readAsStringSync();

      expect(source, contains(r'/DAppVersion=$appVersion'));
      expect(source, contains('pubspec.yaml'));
      expect(
        iss,
        contains('#error AppVersion must be passed in'),
        reason: 'the .iss must refuse to compile with a default version',
      );
    });

    test('stages the Visual C++ runtime the embedder needs', () {
      // Flutter does not copy these and a developer machine has them in System32, so
      // their absence is invisible until it is somebody else's machine.
      final source = script.readAsStringSync();

      for (final dll in [
        'msvcp140.dll',
        'vcruntime140.dll',
        'vcruntime140_1.dll',
      ]) {
        expect(source, contains(dll));
      }
    });
  });
}

/// The body of an Inno Setup `[Section]`, comments and blank lines stripped.
List<String> _section(String iss, String name) {
  final lines = iss.split('\n');
  final start = lines.indexWhere((l) => l.trim() == '[$name]');
  if (start < 0) return const [];

  final body = <String>[];
  for (final line in lines.skip(start + 1)) {
    final trimmed = line.trim();
    if (trimmed.startsWith('[')) break;
    if (trimmed.isEmpty || trimmed.startsWith(';')) continue;
    body.add(trimmed);
  }
  return body;
}
