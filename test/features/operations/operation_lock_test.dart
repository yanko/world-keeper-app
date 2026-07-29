import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:world_keeper/core/errors/exceptions.dart';
import 'package:world_keeper/features/operations/data/operation_lock.dart';

void main() {
  late OperationLock lock;

  setUp(() => lock = OperationLock());

  test('runs a single operation and releases afterwards', () async {
    expect(lock.isBusy, isFalse);

    final result = await lock.run(OperationKind.push, () async {
      expect(lock.isBusy, isTrue);
      expect(lock.current, OperationKind.push);
      return 42;
    });

    expect(result, 42);
    expect(lock.isBusy, isFalse);
    expect(lock.current, isNull);
  });

  test('refuses a second operation while one is running', () async {
    final gate = Completer<void>();
    final first = lock.run(OperationKind.push, () => gate.future);

    await expectLater(
      lock.run(OperationKind.pull, () async {}),
      throwsA(
        isA<OperationBusyException>().having(
          (e) => e.message,
          'message',
          contains('push is already in progress'),
        ),
      ),
    );

    gate.complete();
    await first;
  });

  test('fails fast instead of queueing', () async {
    // A queued operation would begin minutes later against a server whose state has
    // completely changed, having been accepted at a moment the user has forgotten.
    final gate = Completer<void>();
    final first = lock.run(OperationKind.restore, () => gate.future);

    final stopwatch = Stopwatch()..start();
    try {
      await lock.run(OperationKind.push, () async {});
      fail('expected the second operation to be refused');
    } on OperationBusyException {
      stopwatch.stop();
    }
    // Rejected immediately, not after the first finished.
    expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 200)));
    expect(gate.isCompleted, isFalse);

    gate.complete();
    await first;
  });

  test('releases the lock when the operation throws', () async {
    // A failed push must not wedge the app into a state where nothing can start again.
    await expectLater(
      lock.run(OperationKind.push, () async => throw StateError('boom')),
      throwsStateError,
    );

    expect(lock.isBusy, isFalse);
    // And a subsequent operation is accepted.
    await lock.run(OperationKind.pull, () async {});
  });

  test('two callers racing in the same turn cannot both win', () async {
    // The flag is set synchronously before the first await for exactly this reason.
    final gate = Completer<void>();
    final results = <String>[];

    final a = lock
        .run(OperationKind.push, () => gate.future)
        .then((_) => results.add('a-ok'))
        .catchError((Object _) => results.add('a-refused'));
    final b = lock
        .run(OperationKind.pull, () => gate.future)
        .then((_) => results.add('b-ok'))
        .catchError((Object _) => results.add('b-refused'));

    gate.complete();
    await Future.wait([a, b]);

    expect(results, containsAll(['a-ok', 'b-refused']));
  });

  test('sequential operations are all allowed', () async {
    for (final kind in OperationKind.values) {
      await lock.run(kind, () async {});
      expect(lock.isBusy, isFalse);
    }
  });

  test('names the operation that is actually holding it', () async {
    final gate = Completer<void>();
    final first = lock.run(OperationKind.restore, () => gate.future);

    try {
      await lock.run(OperationKind.push, () async {});
      fail('expected a refusal');
    } on OperationBusyException catch (e) {
      expect(e.message, contains('restore'));
      expect(e.context, 'operation');
    }

    gate.complete();
    await first;
  });
}
