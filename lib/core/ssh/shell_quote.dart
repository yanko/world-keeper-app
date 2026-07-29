/// Wraps a string for safe interpolation into a remote shell command.
///
/// Every value this app puts into a command goes through here. It is not optional
/// hardening: the reference worlds path is
/// `/home/steam/.config/unity3d/Pugstorm/Core Keeper/DedicatedServer/worlds` — it
/// contains spaces, and an unquoted `find` against it silently searches the wrong paths
/// rather than failing loudly.
///
/// Uses POSIX single-quoting, where everything is literal and the only character needing
/// care is `'` itself. A single quote is escaped by closing the quoted run, emitting an
/// escaped quote, and reopening: `'` becomes `'\''`.
///
/// ```dart
/// shq("Core Keeper")   // 'Core Keeper'
/// shq("it's")          // 'it'\''s'
/// ```
///
/// A real bug this prevents, from the Rust app's history: `docker inspect --format
/// {{json .Mounts}}` was sent unquoted, so the shell split the format string on its
/// space into two arguments and the mount lookup broke outright.
String shq(String s) => "'${s.replaceAll("'", r"'\''")}'";
